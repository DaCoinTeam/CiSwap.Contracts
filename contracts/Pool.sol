// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./interfaces/IPoolDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
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

contract Pool is IPool, Ownable, ERC20, NoDelegateCall {
    using Oracle for Oracle.Observation[];
    using SafeCast for *;
    using ExtendMath for uint;

    uint24 public constant FEE_PROTOCOL_RATE = 20000;

    address public immutable override factory;
    uint24 public immutable override fee;

    address public immutable override token0;
    address public immutable override token1;

    uint public immutable override constant0;
    uint public immutable override constant1;

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

        (constant0, constant1) = order
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

    function initialize() external override onlyFactory {
        uint adjusted0 = _adjusted0();
        uint adjusted1 = _adjusted1();

        uint observationCardinality = observations.initialize(block.timestamp);

        slot0 = Slot0({
            reserve0: adjusted0,
            reserve1: adjusted1,
            observationCardinality: observationCardinality,
            unlocked: true
        });

        uint liquidityLock = PoolMath.computeLiquidity(adjusted0, adjusted1);

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

        uint constantOut = params.zeroForOne ? constant1 : constant0;
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

        uint feeAmount = _computeFeeProtocol(cache.feeAmount);
        params.zeroForOne
            ? protocolFees.token1 += feeAmount
            : protocolFees.token0 += feeAmount;

        amount0 = params.zeroForOne
            ? -cache.amountIn.toInt256()
            : cache.amountOut.toInt256();
        amount1 = params.zeroForOne
            ? cache.amountOut.toInt256()
            : -cache.amountIn.toInt256();

        if (params.callback.length > 0) {
            ISwapCallee(_msgSender()).swapCall(
                amount0,
                amount1,
                params.callback
            );
        }

        uint adjusted0 = _adjusted0() - (params.zeroForOne ? 0 : feeAmount);
        uint adjusted1 = _adjusted1() - (params.zeroForOne ? feeAmount : 0);

        uint adjustedIn = params.zeroForOne ? adjusted0 : adjusted1;

        require(
            adjustedIn >= cache.reserveIn + cache.amountIn,
            "Insufficient amount input"
        );
        console.log("in %s out %s pool %s", cache.amountIn, cache.amountOut, address(this));

        _update(adjusted0, adjusted1);

        emit Swap(_msgSender(), amount0, amount1, params.recipient);
    }

    function mint(
        address recipient
    ) external override lock noDelegateCall returns (uint amount) {
        uint totalSupply = totalSupply();
        Slot0 memory _slot0 = slot0;
        uint adjusted0 = _adjusted0();
        uint adjusted1 = _adjusted1();

        require(
            adjusted0 > _slot0.reserve0 || adjusted1 > _slot0.reserve1,
            "Insufficient amount transferred"
        );

        amount = PoolMath.computeAmountMint(
            totalSupply,
            _slot0.reserve0,
            _slot0.reserve1,
            adjusted0,
            adjusted1
        );

        _mint(recipient, amount);

        _update(adjusted0, adjusted1);

        emit Mint(
            _msgSender(),
            amount,
            adjusted0 - _slot0.reserve0,
            adjusted1 - _slot0.reserve1,
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
        uint supplyLP = totalSupply();
        require(amount > 0);

        Slot0 memory _slot0 = slot0;

        uint balance0Net = _balance0Net();
        uint balance1Net = _balance1Net();

        (amount0, amount1) = PoolMath.computeAmountsBurn(
            amount,
            supplyLP,
            _slot0.reserve0,
            _slot0.reserve1,
            balance0Net,
            balance1Net
        );

        SafeTransfer.transfer(token0, recipient, amount0);
        SafeTransfer.transfer(token1, recipient, amount1);

        _burn(_msgSender(), amount);

        uint adjusted0 = balance0Net + constant0 - amount0;
        uint adjusted1 = balance1Net + constant1 - amount1;

        _update(adjusted0, adjusted1);

        emit Burn(_msgSender(), amount, amount0, amount1, recipient);
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

        uint adjusted0 = _adjusted0();
        uint adjusted1 = _adjusted1();

        bool result = PoolMath.hasLiquidityGrownAfterFees(
            _slot0.reserve0,
            _slot0.reserve1,
            adjusted0,
            adjusted1,
            fee
        );
        require(result, "Insufficient amounts paid");

        paid0 = adjusted0 - (_slot0.reserve0 - amount0);
        paid1 = adjusted1 - (_slot0.reserve1 - amount1);

        uint feeAmount0 = _computeFeeProtocol(paid0);
        uint feeAmount1 = _computeFeeProtocol(paid1);

        protocolFees.token0 += feeAmount0;
        protocolFees.token1 += feeAmount1;

        _update(adjusted0 - feeAmount0, adjusted1 - feeAmount1);

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

    function _adjusted0() private view returns (uint) {
        return _balance0Net() + constant0;
    }

    function _adjusted1() private view returns (uint) {
        return _balance1Net() + constant1;
    }

    function _computeFeeProtocol(uint amount) private pure returns (uint) {
        return amount.computePercentageOf(FEE_PROTOCOL_RATE);
    }
}
