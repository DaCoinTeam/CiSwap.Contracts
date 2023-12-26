// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IPoolDeployer.sol";

interface IFactory {
    struct CreatePoolParams {
        uint24 fee;
        IPoolDeployer.BootstrapConfig config;
    }

    event FeeAmountEnabled(uint24 indexed fee);

    event PoolCreated(
        address indexed sender,
        IPoolDeployer.BootstrapConfig config,
        address pool
    );

    function createPool(
        CreatePoolParams calldata params
    ) external returns (address pool);

    function getPool(
        address tokenA,
        address tokenB,
        uint index
    ) external view returns (address);

    function getFeeAmountEnabled(uint24 fee) external returns (bool);

    function pools(uint index) external view returns (address);

    function feeTo() external view returns (address);
    function setFeeTo(address account) external;
}
