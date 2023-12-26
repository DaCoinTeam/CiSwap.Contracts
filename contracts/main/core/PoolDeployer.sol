// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./interfaces/IPoolDeployer.sol";
import "./Pool.sol";

abstract contract PoolDeployer is IPoolDeployer {
    DeployParams public override deployParams;

    function deploy(
        DeployParams memory params
    ) internal returns (address pool) {
        deployParams = params;
        pool = address(new Pool());
        delete deployParams;
    }
}
