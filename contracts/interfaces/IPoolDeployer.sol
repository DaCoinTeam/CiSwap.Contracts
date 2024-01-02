// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IPoolDeployer {
    struct BootstrapConfig {
        address tokenA;
        address tokenB;
        uint amountA;
        uint amountB;
        uint priceABaseX96;
        uint priceAMaxX96;
    }

    struct DeployParams {
        address factory;
        uint24 fee;
        BootstrapConfig config;
    }

    function deployParams()
        external
        view
        returns (address factory, uint24 fee, BootstrapConfig memory config);
}
