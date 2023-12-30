// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./interfaces/IPoolDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "./libraries/ExtendMath.sol";
import "./libraries/SafeTransfer.sol";
import "./libraries/TokenLib.sol";
import "./libraries/PoolMath.sol";
import "./interfaces/IFactory.sol";
import "./libraries/Oracle.sol";
import "./base/NoDelegateCall.sol";
import "./interfaces/pool/IPool.sol";
import "./interfaces/callee/ISwapCallee.sol";
import "./interfaces/callee/IFlashCallee.sol";
import "./interfaces/callee/IMintCallee.sol";
import "./interfaces/callee/IBurnCallee.sol";

contract Pool is IPool, Ownable, ERC20, NoDelegateCall, Multicall {
    using Oracle for Oracle.Observation[];
    using SafeCast for *;
    using ExtendMath for uint;

    uint24 public constant FEE_PROTOCOL_RATE = 20000;

    address public immutable override factory;
    uint24 public immutable override fee;

    address public immutable override token0;
    address public immutable override token1;
    uint32 public override indexPool;

    IPoolDeployer.BootstrapConfig public override config;

    Oracle.Observation[] public override observations;

    struct Slot0 {
        uint reserve0;
        uint reserve1;
        uint observationCardinality;
        bool unlocked;
    }
    Slot0 public override slot0;

    struct ProtocolFees {
        uint token0;
        uint token1;
    }
    ProtocolFees public override protocolFees;

    struct Constants {
        uint token0;
        uint token1;
    }
    Constants public override constants;

    constructor()
        Ownable(_msgSender())
        ERC20("Liquidity Provider Token", "LP Token")
    {
        (factory, fee, config) = IPoolDeployer(_msgSender()).deployParams();
        bool order;
        (token0, token1, order) = TokenLib.sortTokens(
            config.tokenA,
            config.tokenB
        );

        (uint constantA, uint constantB) = PoolMath.computeConstants(
            config.basePriceAX96,
            config.maxPriceAX96,
            config.amountA,
            config.amountB
        );

        (constants.token0, constants.token1) = order
            ? (constantA, constantB)
            : (constantB, constantA);
    }

    modifier lock() {
        require(slot0.unlocked, "Lock");
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    modifier onlyFactory() {
        require(_msgSender() == factory);
        _;
    }

    function _update(uint reserve0, uint reserve1) internal {
        slot0.reserve0 = reserve0;
        slot0.reserve1 = reserve1;

        Slot0 memory _slot0 = slot0;

        slot0.observationCardinality = observations.write(
            _slot0.observationCardinality,
            block.timestamp,
            reserve0,
            reserve1
        );

        emit Sync(reserve0, reserve1);
    }

    function observe(
        uint[] calldata secondAgos
    )
        external
        view
        override
        returns (
            uint[] memory reserve0Cumulatives,
            uint[] memory reserve1Cumulatives
        )
    {
        Slot0 memory _slot0 = slot0;
        return
            observations.observe(
                block.timestamp,
                _slot0.reserve0,
                _slot0.reserve1,
                _slot0.observationCardinality,
                secondAgos
            );
    }

    function price0X96() external view override returns (uint) {
        Slot0 memory _slot0 = slot0;
        return
            PoolMath.computePriceX96(
                _slot0.reserve0,
                _slot0.reserve1,
                fee,
                true
            );
    }

    function price1X96() external view override returns (uint) {
        Slot0 memory _slot0 = slot0;
        return
            PoolMath.computePriceX96(
                _slot0.reserve0,
                _slot0.reserve1,
                fee,
                false
            );
    }

    function liquidity() external view override returns (uint) {
        Slot0 memory _slot0 = slot0;
        return PoolMath.computeLiquidity(_slot0.reserve0, _slot0.reserve1);
    }

    function initialize(uint32 _indexPool) external override onlyFactory {
        indexPool = _indexPool;

        uint balance0NetWithConstant = _balance0NetWithConstant();
        uint balance1NetWithConstant = _balance1NetWithConstant();

        uint observationCardinality = observations.initialize(block.timestamp);

        slot0 = Slot0({
            reserve0: balance0NetWithConstant,
            reserve1: balance1NetWithConstant,
            observationCardinality: observationCardinality,
            unlocked: true
        });

        uint liquidityLock = PoolMath.computeLiquidity(
            balance0NetWithConstant,
            balance1NetWithConstant
        );

        _mint(address(this), liquidityLock);

        emit Initialized();
    }

    struct SwapCache {
        address tokenIn;
        address tokenOut;
        uint amountIn;
        uint amountOut;
        uint reserveIn;
        uint reserveOut;
        uint actualIn;
        uint actualOut;
        uint feeAmount;
    }

    function swap(
        SwapParams calldata params
    ) external override lock noDelegateCall returns (int amount0, int amount1) {
        Slot0 memory _slot0 = slot0;
        SwapCache memory cache;
        (cache.tokenIn, cache.tokenOut) = params.zeroForOne
            ? (token0, token1)
            : (token1, token0);

        (cache.reserveIn, cache.reserveOut) = params.zeroForOne
            ? (_slot0.reserve0, _slot0.reserve1)
            : (_slot0.reserve1, _slot0.reserve0);

        uint constantOut = params.zeroForOne
            ? constants.token1
            : constants.token0;
        bool exactInput = params.amountSpecified > 0;
        if (exactInput) {
            cache.amountIn = params.amountSpecified.toUint256();
            (cache.amountOut, cache.feeAmount) = PoolMath.computeAmountOut(
                PoolMath.ComputeAmountOutParams({
                    reserveIn: params.zeroForOne
                        ? _slot0.reserve0
                        : _slot0.reserve1,
                    reserveOut: params.zeroForOne
                        ? _slot0.reserve1
                        : _slot0.reserve0,
                    constantOut: constantOut,
                    amountIn: cache.amountIn,
                    fee: fee
                })
            );
            require(
                cache.amountOut >= params.limitAmountCalculated,
                "Output limit exceeded"
            );
        } else {
            cache.amountOut = (-params.amountSpecified).toUint256();
            (cache.amountIn, cache.feeAmount) = PoolMath.computeAmountIn(
                PoolMath.ComputeAmountInParams({
                    reserveIn: params.zeroForOne
                        ? _slot0.reserve0
                        : _slot0.reserve1,
                    reserveOut: params.zeroForOne
                        ? _slot0.reserve1
                        : _slot0.reserve0,
                    constantOut: constantOut,
                    amountOut: cache.amountOut,
                    fee: fee
                })
            );
            require(
                cache.amountIn <= params.limitAmountCalculated,
                "Input limit exceeded"
            );
        }

        SafeTransfer.transfer(
            cache.tokenOut,
            params.recipient,
            cache.amountOut
        );

        amount0 = params.zeroForOne
            ? -cache.amountIn.toInt256()
            : cache.amountOut.toInt256();
        amount1 = params.zeroForOne
            ? cache.amountOut.toInt256()
            : -cache.amountIn.toInt256();

        uint feeAmount = _computeFeeProtocol(cache.feeAmount);
        console.log("fee %s", feeAmount);
        params.zeroForOne
            ? protocolFees.token1 += feeAmount
            : protocolFees.token0 += feeAmount;

        if (params.callback.length > 0) {
            ISwapCallee(_msgSender()).swapCall(
                amount0,
                amount1,
                params.callback
            );
        }
        uint balance0NetWithConstant = _balance0NetWithConstant();
        uint balance1NetWithConstant = _balance1NetWithConstant();

        uint balanceInNetPlusConstantIn = params.zeroForOne
            ? balance0NetWithConstant
            : balance1NetWithConstant;

        require(
            balanceInNetPlusConstantIn >= cache.reserveIn + cache.amountIn,
            "Insufficient amount input"
        );
        console.log(
            "in %s out %s pool %s",
            cache.amountIn,
            cache.amountOut,
            address(this)
        );

        uint balance0NetWithConstantAfterFee = balance0NetWithConstant;
        uint balance1NetWithConstantAfterFee = balance1NetWithConstant;
        if (params.zeroForOne) {
            balance1NetWithConstantAfterFee -= feeAmount;
        }
        if (params.zeroForOne) {
            balance0NetWithConstantAfterFee -= feeAmount;
        }

        _update(
            balance0NetWithConstantAfterFee,
            balance1NetWithConstantAfterFee
        );

        emit Swap(_msgSender(), amount0, amount1, params.recipient);
    }

    function mint(
        address recipient
    ) external override lock noDelegateCall returns (uint amount) {
        uint _totalSupply = totalSupply();
        Slot0 memory _slot0 = slot0;

        uint balance0NetWithConstant = _balance0NetWithConstant();
        uint balance1NetWithConstant = _balance1NetWithConstant();

        require(
            balance0NetWithConstant > _slot0.reserve0 ||
                balance1NetWithConstant > _slot0.reserve1,
            "Insufficient amount transferred"
        );

        uint constant0Increment;
        uint constant1Increment;
        (amount, constant0Increment, constant1Increment) = PoolMath
            .computeMintAmountAndConstantIncrements(
                _totalSupply,
                _slot0.reserve0,
                _slot0.reserve1,
                balance0NetWithConstant,
                balance1NetWithConstant
            );

        _mint(recipient, amount);

        uint balance0NetWithConstantUpdated = balance0NetWithConstant;
        uint balance1NetWithConstantUpdated = balance1NetWithConstant;
        if (constant0Increment > 0) {
            constants.token0 += constant0Increment;
            balance0NetWithConstantUpdated += constant0Increment;
        }
        if (constant1Increment > 0) {
            constants.token1 += constant1Increment;
            balance1NetWithConstantUpdated += constant1Increment;
        }

        _update(balance0NetWithConstantUpdated, balance1NetWithConstantUpdated);

        emit Mint(
            _msgSender(),
            amount,
            balance0NetWithConstant - _slot0.reserve0,
            balance1NetWithConstant - _slot0.reserve1,
            recipient
        );
    }

    function burn(
        address recipient,
        uint amount
    )
        external
        override
        lock
        noDelegateCall
        returns (uint amount0, uint amount1)
    {
        uint _totalSupply = totalSupply();
        require(amount > 0);

        Slot0 memory _slot0 = slot0;

        uint balance0Net = _balance0Net();
        uint balance1Net = _balance1Net();

        uint constant0Decrement;
        uint constant1Decrement;
        (amount0, amount1, constant0Decrement, constant1Decrement) = PoolMath
            .computeBurnAmountsAndConstantDecrements(
                amount,
                _totalSupply,
                _slot0.reserve0,
                _slot0.reserve1,
                balance0Net,
                balance1Net
            );

        SafeTransfer.transfer(token0, recipient, amount0);
        SafeTransfer.transfer(token1, recipient, amount1);

        _burn(_msgSender(), amount);

        uint balance0NetWithConstant = balance0Net + constants.token0 - amount0;
        uint balance1NetWithConstant = balance1Net + constants.token1 - amount1;

        uint balance0NetWithConstantUpdated = balance0NetWithConstant;
        uint balance1NetWithConstantUpdated = balance1NetWithConstant;
        if (constant0Decrement > 0) {
            constants.token0 -= constant0Decrement;
            balance0NetWithConstantUpdated -= constant0Decrement;
        }
        if (constant1Decrement > 0) {
            constants.token1 -= constant1Decrement;
            balance1NetWithConstantUpdated -= constant1Decrement;
        }
        _update(balance0NetWithConstantUpdated, balance1NetWithConstantUpdated);

        emit Burn(_msgSender(), amount, amount0, amount1, recipient);
    }

    struct FlashPostCallbackState {
        uint feeAmount0;
        uint feeAmount1;
        uint balance0NetWithConstant;
        uint balance1NetWithConstant;
        uint balance0NetWithConstantAfterFee;
        uint balance1NetWithConstantAfterFee;
    }

    function flash(
        address recipient,
        uint amount0,
        uint amount1,
        bytes calldata callback
    ) external override lock noDelegateCall returns (uint paid0, uint paid1) {
        SafeTransfer.transfer(token0, recipient, amount0);
        SafeTransfer.transfer(token1, recipient, amount1);

        IFlashCallee(_msgSender()).flashCall(amount0, amount1, callback);

        Slot0 memory _slot0 = slot0;

        FlashPostCallbackState memory state;

        state.balance0NetWithConstant = _balance0NetWithConstant();
        state.balance1NetWithConstant = _balance1NetWithConstant();

        bool result = PoolMath.hasLiquidityGrownAfterFees(
            _slot0.reserve0,
            _slot0.reserve1,
            state.balance0NetWithConstant,
            state.balance1NetWithConstant,
            fee
        );
        require(result, "Insufficient amounts paid");

        paid0 = state.balance0NetWithConstant - (_slot0.reserve0 - amount0);
        paid1 = state.balance1NetWithConstant - (_slot0.reserve1 - amount1);

        uint feeAmount0 = _computeFeeProtocol(paid0);
        uint feeAmount1 = _computeFeeProtocol(paid1);

        protocolFees.token0 += feeAmount0;
        protocolFees.token1 += feeAmount1;

        state.balance0NetWithConstantAfterFee =
            state.balance0NetWithConstant -
            feeAmount0;
        state.balance1NetWithConstantAfterFee =
            state.balance1NetWithConstant -
            feeAmount1;

        _update(
            state.balance0NetWithConstantAfterFee,
            state.balance1NetWithConstantAfterFee
        );

        emit Flash(_msgSender(), amount0, amount1, paid0, paid1, recipient);
    }

    function collectProtocol(
        address recipient,
        uint amount0Requested,
        uint amount1Requested
    )
        external
        override
        onlyOwner
        returns (
            uint amount0,
            uint amount1,
            uint amountFeeTo0,
            uint amountFeeTo1
        )
    {
        uint amount0Gross = amount0Requested;

        if (amount0Requested > protocolFees.token0)
            amount0Gross = protocolFees.token0;

        uint amount1Gross = amount1Requested;
        if (amount1Requested > protocolFees.token1)
            amount1Gross = protocolFees.token1;

        address feeTo = IFactory(factory).feeTo();

        amountFeeTo0 = _computeFeeProtocol(amount0Gross);
        amountFeeTo1 = _computeFeeProtocol(amount1Gross);
        amount0 = amount0Gross - amountFeeTo0;
        amount1 = amount1Gross - amountFeeTo1;

        SafeTransfer.transfer(token0, recipient, amount0);
        SafeTransfer.transfer(token1, recipient, amount1);
        SafeTransfer.transfer(token0, feeTo, amountFeeTo0);
        SafeTransfer.transfer(token1, feeTo, amountFeeTo0);

        protocolFees.token0 -= amount0Gross;
        protocolFees.token1 -= amount1Gross;

        emit CollectProtocol(
            recipient,
            amount0,
            amount1,
            amountFeeTo0,
            amountFeeTo1,
            recipient
        );
    }

    function _balance0() private view returns (uint) {
        return IERC20(token0).balanceOf(address(this));
    }

    function _balance1() private view returns (uint) {
        return IERC20(token1).balanceOf(address(this));
    }

    function _balance0Net() private view returns (uint) {
        return _balance0() - protocolFees.token0;
    }

    function _balance1Net() private view returns (uint) {
        return _balance1() - protocolFees.token1;
    }

    function _balance0NetWithConstant() private view returns (uint) {
        return _balance0Net() + constants.token0;
    }

    function _balance1NetWithConstant() private view returns (uint) {
        return _balance1Net() + constants.token1;
    }

    function _computeFeeProtocol(uint amount) private pure returns (uint) {
        return amount.computePercentageOf(FEE_PROTOCOL_RATE);
    }
}
