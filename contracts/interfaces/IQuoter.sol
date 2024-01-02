// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IQuoter {
    function quoteExactInput(
        uint amountIn,
        bytes memory path
    ) external returns (uint amountOut);

    function quoteExactInputSingle(
        uint amountIn,
        address tokenIn,
        address tokenOut,
        uint32 indexPool
    ) external returns (uint amountOut);

    function quoteExactOutput(
        uint amountOut,
        bytes memory path
    ) external returns (uint amountIn);

    function quoteExactOutputSingle(
        uint amountOut,
        address tokenIn,
        address tokenOut,
        uint32 indexPool
    ) external returns (uint amountIn);

     function quotePriceX96(
        bytes memory path
    ) external returns (uint priceX96);
}
