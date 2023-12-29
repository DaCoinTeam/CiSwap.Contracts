// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IBurnCallee {
    function burnCall(uint256 amount, bytes calldata callback) external;
}
