// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../../core/interfaces/IPoolDeployer.sol";
import "../../core/interfaces/IFactory.sol";
import "../../core/Pool.sol";
import "../../core/interfaces/pool/IPool.sol";
import "./PeripheryImmutables.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PeripheryPoolManagement is PeripheryImmutables {
    using SafeERC20 for IERC20;

    function _getPool(
        address tokenA,
        address tokenB,
        uint32 indexPool
    ) internal view returns (address pool) {
        pool = IFactory(factory).getPool(tokenA, tokenB, indexPool);
        require(pool != address(0));
    }
}
