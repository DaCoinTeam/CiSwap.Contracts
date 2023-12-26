// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

abstract contract PeripheryValidation {
    modifier checkDeadline(uint32 deadline) {
        require(deadline >= block.timestamp);
        _;
    }
}
