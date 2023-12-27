// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IQuoter {
    function quoteExactInput(
        bytes memory path,
        uint amountIn
    ) external returns (uint amountOut);

    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint32 indexPool,
        uint amountIn
    ) external returns (uint amountOut);

    function quoteExactOutput(
        bytes memory path,
        uint amountOut
    ) external returns (uint amountIn);

    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint32 indexPool,
        uint amountOut
    ) external returns (uint amountIn);
}
