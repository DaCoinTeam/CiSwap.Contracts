// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.23;

interface IQuoter {
    function quoteExactInput(
        bytes memory path,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint32 indexPool,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function quoteExactOutput(
        bytes memory path,
        uint256 amountOut
    ) external returns (uint256 amountIn);

    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint32 indexPool,
        uint256 amountOut
    ) external returns (uint256 amountIn);
}
