// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../IPoolDeployer.sol";

interface IPoolEvents {
    event Initialized();

    event Swap(
        address indexed sender,
        int256 amount0,
        int256 amount1,
        address indexed recipient
    );

    event Mint(
        address indexed sender,
        uint amount,
        uint feeToOwner,
        uint amount0,
        uint amount1,
        address indexed recipient
    );

    event Burn(
        address indexed sender,
        uint amount,
        uint amount0,
        uint amount1,
        address indexed recipient
    );

    event Flash(
        address indexed sender,
        uint amount0,
        uint amount1,
        uint paid0,
        uint paid1,
        address indexed recipient
    );

    event Sync(uint256 reserve0, uint256 reserve1);
}
