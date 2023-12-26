// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IFlashCallee {
    function flashCall(
        uint256 amount0,
        uint256 amount1,
        bytes calldata callback
    ) external;
}