// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "../core/interfaces/pool/IPool.sol";
import "./interfaces/IRouter.sol";
import "../core/interfaces/callee/ISwapCallee.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../core/interfaces/pool/IPoolActions.sol";
import "./base/PeripheryValidation.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../core/interfaces/pool/IPoolActions.sol";
import "../shared/libraries/TokenLib.sol";
import "../core/libraries/PoolMath.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "../shared/base/ExtendMulticall.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./libraries/Path.sol";
import "./base/PeripheryPoolManagement.sol";
import "./base/PeripheryPayment.sol";
import "../shared/libraries/SafeTransfer.sol";

contract Router is
    IRouter,
    ISwapCallee,
    Context,
    PeripheryValidation,
    PeripheryPoolManagement,
    PeripheryPayment,
    ExtendMulticall
{
    using SafeCast for *;
    using Path for bytes;
    using SignedMath for int256;
    using Math for uint;

    constructor(
        address _factory,
        address _WETH10
    ) PeripheryImmutables(_factory, _WETH10) {}

    struct AddLiquidityCache {
        address token0;
        address token1;
        bool order;
        uint amount0;
        uint amount1;
    }

    function addLiquidity(
        AddLiquidityParams calldata params
    )
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint amount)
    {
        AddLiquidityCache memory cache;

        (cache.token0, cache.token1, cache.order) = TokenLib.sortTokens(
            params.tokenA,
            params.tokenB
        );
        address pool = _getPool(cache.token0, cache.token1, params.indexPool);
        (cache.amount0, cache.amount1) = cache.order
            ? (params.amountA, params.amountB)
            : (params.amountB, params.amountA);

        SafeTransfer.transferFrom(
            cache.token0,
            _msgSender(),
            pool,
            cache.amount0
        );
        SafeTransfer.transferFrom(
            cache.token1,
            _msgSender(),
            pool,
            cache.amount1
        );
        (amount, ) = IPool(pool).mint(params.recipient);
        require(amount >= params.amountMin);
    }

    function removeLiquidity(
        RemoveLiquidityParams calldata params
    )
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint amount0, uint amount1)
    {
        (address token0, address token1, bool order) = TokenLib.sortTokens(
            params.tokenA,
            params.tokenB
        );
        (uint amount0Min, uint amount1Min) = order
            ? (params.amountAMin, params.amountBMin)
            : (params.amountBMin, params.amountAMin);

        address pool = _getPool(token0, token1, params.indexPool);

        IERC20(pool).transferFrom(_msgSender(), address(this), params.amount);
        (amount0, amount1) = IPool(pool).burn(params.recipient, params.amount);

        require(amount0 >= amount0Min && amount1 > amount1Min);
    }

    struct SwapCallbackData {
        address payer;
        bytes path;
    }

    function swapCall(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata callback
    ) external {
        require(amount0Delta > 0 || amount1Delta > 0, "...");

        //data
        SwapCallbackData memory data = abi.decode(callback, (SwapCallbackData));

        (address tokenStart, address tokenEnd, uint32 indexPool) = data
            .path
            .decodeFirstPool();

        //verify purpose only
        _getPool(tokenStart, tokenEnd, indexPool);

        (bool isExactInput, uint amountIn) = amount0Delta < 0
            ? (tokenStart < tokenEnd, (-amount0Delta).toUint256()) // nếu theo chiều thuận, thì tokenIn trade cho tokenOut, mà out là 0 => int là 1. case này trade nghịch thì in
            : (tokenStart > tokenEnd, (-amount1Delta).toUint256());

        if (isExactInput) {
            _pay(tokenStart, data.payer, _msgSender(), amountIn);
        } else {
            if (data.path.hasMultiplePools()) {
                bytes memory path = data.path.skipToken();

                _exactOutputInternal(
                    amountIn,
                    _msgSender(),
                    SwapCallbackData({payer: data.payer, path: path})
                );
            } else {
                _pay(tokenEnd, data.payer, _msgSender(), amountIn);
            }
        }
    }

    function _exactInputInternal(
        uint amountIn,
        address recipient,
        SwapCallbackData memory data
    ) internal returns (uint amountOut) {
        (address tokenIn, address tokenOut, uint32 indexPool) = data
            .path
            .decodeFirstPool();

        address pool = _getPool(tokenIn, tokenOut, indexPool);
        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0, int256 amount1) = IPool(pool).swap(
            IPoolActions.SwapParams({
                amountSpecified: amountIn.toInt256(),
                limitAmountCalculated: 0,
                zeroForOne: zeroForOne,
                recipient: recipient,
                callback: abi.encode(data)
            })
        );

        amountOut = amount0 > 0 ? amount0.toUint256() : amount1.toUint256();
    }

    function exactInput(
        ExactInputParams memory params
    )
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint amountOut)
    {
        address payer = _msgSender();

        while (true) {
            bool hasMultiplePools = params.path.hasMultiplePools();
            console.log(hasMultiplePools);
            //
            params.amountIn = _exactInputInternal(
                params.amountIn,
                hasMultiplePools ? address(this) : params.recipient,
                SwapCallbackData({
                    path: params.path.getFirstPool(),
                    payer: payer
                })
            );
            if (hasMultiplePools) {
                payer = address(this);
                params.path = params.path.skipToken();
            } else {
                amountOut = params.amountIn;
                break;
            }
        }
        require(amountOut >= params.amountOutMin, "Too little received.");
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    )
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint amountOut)
    {
        amountOut = _exactInputInternal(
            params.amountIn,
            params.recipient,
            SwapCallbackData({
                payer: _msgSender(),
                path: abi.encodePacked(
                    params.tokenIn,
                    params.indexPool,
                    params.tokenOut
                )
            })
        );
        require(
            amountOut >= params.amountOutMin,
            "The output amount must be greater than or equal to the minimum specified amount."
        );
    }

    //function
    function _exactOutputInternal(
        uint amountOut,
        address recipient,
        SwapCallbackData memory data
    ) internal returns (uint amountIn) {
        (address tokenOut, address tokenIn, uint32 indexPool) = data
            .path
            .decodeFirstPool();

        address pool = _getPool(tokenIn, tokenOut, indexPool);
        bool zeroForOne = tokenIn < tokenOut;

        //proccess swap
        (int256 amount0, int256 amount1) = IPool(pool).swap(
            IPoolActions.SwapParams({
                amountSpecified: -amountOut.toInt256(),
                limitAmountCalculated: type(uint).max,
                zeroForOne: zeroForOne,
                recipient: recipient,
                callback: abi.encode(data)
            })
        );

        amountIn = amount0 < 0
            ? (-amount0).toUint256()
            : (-amount1).toUint256();
    }

    function exactOutput(
        ExactOutputParams calldata params
    )
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint amountIn)
    {
        amountIn = _exactOutputInternal(
            params.amountOut,
            params.recipient,
            SwapCallbackData({payer: _msgSender(), path: params.path})
        );

        require(
            amountIn <= params.amountInMax,
            "Exceeded maximum allowable input amount."
        );
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    )
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint amountIn)
    {
        amountIn = _exactOutputInternal(
            params.amountOut,
            params.recipient,
            SwapCallbackData({
                payer: _msgSender(),
                path: abi.encodePacked(
                    params.tokenOut,
                    params.indexPool,
                    params.tokenIn
                )
            })
        );
        require(
            amountIn <= params.amountInMax,
            "Exceeded maximum allowable input amount."
        );
    }
}
