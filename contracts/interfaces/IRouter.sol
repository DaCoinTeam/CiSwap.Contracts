// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IRouter {
    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint32 indexPool;
        uint256 amountA;
        uint256 amountB;
        uint256 amountMin;
        address recipient;
        uint32 deadline;
    }

    function addLiquidity(
        AddLiquidityParams calldata params
    ) external payable returns (uint256 amount);

    struct RemoveLiquidityParams {
        address tokenA;
        address tokenB;
        uint32 indexPool;
        uint256 amount;
        uint256 amountAMin;
        uint256 amountBMin;
        address recipient;
        uint32 deadline;
    }

    function removeLiquidity(
        RemoveLiquidityParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);

    struct ExactInputParams {
        uint256 amountIn;
        uint256 amountOutMin;
        address recipient;
        bytes path;
        uint32 deadline;
    }

    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactInputSingleParams {
        uint256 amountIn;
        uint256 amountOutMin;
        address recipient;
        address tokenIn;
        address tokenOut;
        uint32 indexPool;
        uint32 deadline;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactOutputParams {
        uint256 amountOut;
        uint256 amountInMax;
        address recipient;
        bytes path;
        uint32 deadline;
    }

    function exactOutput(
        ExactOutputParams calldata params
    ) external payable returns (uint256 amountIn);

    struct ExactOutputSingleParams {
        uint256 amountOut;
        uint256 amountInMax;
        address recipient;
        address tokenIn;
        address tokenOut;
        uint32 indexPool;
        uint32 deadline;
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}
