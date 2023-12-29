// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./interfaces/pool/IPool.sol";
import "./interfaces/IQuoter.sol";
import "./interfaces/callee/ISwapCallee.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interfaces/pool/IPoolActions.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/pool/IPoolActions.sol";
import "./libraries/TokenLib.sol";
import "./libraries/PoolMath.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./libraries/Path.sol";
import "./base/PeripheryPoolManagement.sol";

contract Quoter is IQuoter, ISwapCallee, Context, PeripheryPoolManagement {
    using Path for bytes;
    using SafeCast for *;

    uint private constant MAX = type(uint).max;

    constructor(
        address _factory,
        address _WETH10
    ) PeripheryImmutables(_factory, _WETH10) {}

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        uint32 indexPool,
        uint amount0,
        uint amount1
    ) external returns (uint) {}

    function quoteRemoveLiquidity(
        uint amount,
        address tokenA,
        address tokenB,
        uint32 indexPool
    ) external returns (uint) {}

    function swapCall(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata callback
    ) external view override {
        require(amount0Delta > 0 || amount1Delta > 0);
        (address tokenStart, address tokenEnd, uint32 indexPool) = callback
            .decodeFirstPool();
        _getPool(tokenStart, tokenEnd, indexPool);

        (bool isExactInput, uint amountIn, uint amountOut) = amount0Delta < 0
            ? (
                tokenStart < tokenEnd,
                (-amount0Delta).toUint256(),
                amount1Delta.toUint256()
            )
            : (
                tokenEnd < tokenStart,
                (-amount1Delta).toUint256(),
                amount0Delta.toUint256()
            );
        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountOut)
                revert(ptr, 32)
            }
        } else {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountIn)
                revert(ptr, 32)
            }
        }
    }

    function quoteExactInput(
        uint amountIn,
        bytes memory path
    ) external override returns (uint amountOut) {
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            (address tokenIn, address tokenOut, uint32 indexPool) = path
                .decodeFirstPool();

            amountIn = quoteExactInputSingle(
                amountIn,
                tokenIn,
                tokenOut,
                indexPool
            );

            if (hasMultiplePools) {
                path = path.skipToken();
            } else {
                return amountIn;
            }
        }
    }

    function quoteExactInputSingle(
        uint amountIn,
        address tokenIn,
        address tokenOut,
        uint32 indexPool
    ) public override returns (uint amountOut) {
        bool zeroForOne = tokenIn < tokenOut;

        address pool = _getPool(tokenIn, tokenOut, indexPool);
        try
            IPool(pool).swap(
                IPoolActions.SwapParams({
                    amountSpecified: amountIn.toInt256(),
                    limitAmountCalculated: 0,
                    zeroForOne: zeroForOne,
                    recipient: address(this),
                    callback: abi.encodePacked(tokenIn, indexPool, tokenOut)
                })
            )
        {} catch (bytes memory reason) {
            console.log("nomna %s", _parseRevertReason(reason));
            return _parseRevertReason(reason);
        }
    }

    function quoteExactOutput(
        uint amountOut,
        bytes memory path
    ) external override returns (uint amountIn) {
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            (address tokenOut, address tokenIn, uint32 indexPool) = path
                .decodeFirstPool();

            amountOut = quoteExactOutputSingle(
                amountOut,
                tokenIn,
                tokenOut,
                indexPool
            );

            if (hasMultiplePools) {
                path = path.skipToken();
            } else {
                return amountOut;
            }
        }
    }

    function quoteExactOutputSingle(
        uint amountOut,
        address tokenIn,
        address tokenOut,
        uint32 indexPool
    ) public override returns (uint amountIn) {
        bool zeroForOne = tokenIn < tokenOut;
        address pool = _getPool(tokenIn, tokenOut, indexPool);
        try
            IPool(pool).swap(
                IPoolActions.SwapParams({
                    amountSpecified: -amountOut.toInt256(),
                    limitAmountCalculated: type(uint).max,
                    zeroForOne: zeroForOne,
                    recipient: address(this),
                    callback: abi.encodePacked(tokenOut, indexPool, tokenIn)
                })
            )
        {} catch (bytes memory reason) {
            return _parseRevertReason(reason);
        }
    }

    function _parseRevertReason(
        bytes memory reason
    ) private pure returns (uint) {
        return reason.length != 32 ? 0 : abi.decode(reason, (uint));
    }
}
