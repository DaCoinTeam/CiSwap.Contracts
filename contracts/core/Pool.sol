// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./interfaces/IPoolDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../shared/libraries/SafeTransfer.sol";
import "../shared/libraries/TokenLib.sol";
import "./libraries/PoolMath.sol";
import "./libraries/Oracle.sol";
import "../shared/base/NoDelegateCall.sol";
import "./interfaces/pool/IPool.sol";
import "./interfaces/callee/ISwapCallee.sol";
import "./interfaces/callee/IFlashCallee.sol";

contract Pool is IPool, Ownable, ERC20, NoDelegateCall {
    using Oracle for Oracle.Observation[];
    using SafeCast for *;

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
        require(slot0.unlocked);
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    modifier onlyFactory() {
        require(_msgSender() == factory);
        _;
    }

    function _update(uint adjusted0, uint adjusted1) internal {
        slot0.reserve0 = adjusted0;
        slot0.reserve1 = adjusted1;

        Slot0 memory _slot0 = slot0;

        slot0.observationCardinality = observations.write(
            _slot0.observationCardinality,
            block.timestamp,
            _slot0.reserve0,
            _slot0.reserve1
        );

        emit Sync(_slot0.reserve0, _slot0.reserve1);
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
        return
            observations.observe(
                block.timestamp,
                slot0.observationCardinality,
                secondAgos
            );
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
            cache.amountOut = PoolMath.computeAmountOut(
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
            require(cache.amountOut >= params.limitAmountCalculated);
        } else {
            cache.amountOut = (-params.amountSpecified).toUint256();
            cache.amountIn = PoolMath.computeAmountIn(
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
            require(cache.amountIn <= params.limitAmountCalculated);
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

        if (params.callback.length > 0) {
            ISwapCallee(_msgSender()).swapCall(
                amount0,
                amount1,
                params.callback
            );
        }

        uint adjusted0 = _adjusted0();
        uint adjusted1 = _adjusted1();

        uint adjustedIn = params.zeroForOne ? adjusted0 : adjusted1;

        require(adjustedIn >= cache.reserveIn + cache.amountIn);

        _update(adjusted0, adjusted1);

        emit Swap(_msgSender(), amount0, amount1, params.recipient);
    }

    function mint(
        address recipient
    )
        external
        override
        lock
        noDelegateCall
        returns (uint amount, uint feeToOwner)
    {
        uint totalSupply = totalSupply();
        Slot0 memory _slot0 = slot0;
        uint adjusted0 = _adjusted0();
        uint adjusted1 = _adjusted1();

        require(adjusted0 > _slot0.reserve0 || adjusted1 > _slot0.reserve1);

        (amount, feeToOwner) = PoolMath.computeAmountMint(
            totalSupply,
            _slot0.reserve0,
            _slot0.reserve1,
            adjusted0,
            adjusted1,
            fee
        );

        _mint(recipient, amount);
        _mint(owner(), feeToOwner);

        _update(adjusted0, adjusted1);

        emit Mint(
            _msgSender(),
            amount,
            feeToOwner,
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

        uint balance0 = _balance0();
        uint balance1 = _balance1();

        (amount0, amount1) = PoolMath.computeAmountsBurn(
            amount,
            supplyLP,
            _slot0.reserve0,
            _slot0.reserve1,
            balance0,
            balance1
        );

        SafeTransfer.transfer(token0, recipient, amount0);
        SafeTransfer.transfer(token1, recipient, amount1);

        _burn(_msgSender(), amount);

        uint adjusted0 = balance0 + constant0 - amount0;
        uint adjusted1 = balance1 + constant1 - amount1;

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

        require(
            PoolMath.hasLiquidityGrownAfterFees(
                _slot0.reserve0,
                _slot0.reserve1,
                adjusted0,
                adjusted1,
                fee
            )
        );

        paid0 = adjusted0 - _slot0.reserve0;
        paid1 = adjusted1 - _slot0.reserve1;

        _update(adjusted0, adjusted1);

        emit Flash(_msgSender(), amount0, amount1, paid0, paid1, recipient);
    }

    function _balance0() private view returns (uint) {
        return IERC20(token0).balanceOf(address(this));
    }

    function _balance1() private view returns (uint) {
        return IERC20(token1).balanceOf(address(this));
    }

    function _adjusted0() private view returns (uint) {
        return _balance0() + constant0;
    }

    function _adjusted1() private view returns (uint) {
        return _balance1() + constant1;
    }
}
