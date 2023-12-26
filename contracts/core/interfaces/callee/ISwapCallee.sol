// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface ISwapCallee {
    function swapCall(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata callback
    ) external;
}
