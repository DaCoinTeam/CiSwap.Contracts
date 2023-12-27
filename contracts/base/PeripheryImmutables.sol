// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/periphery/IPeripheryImmutables.sol";

abstract contract PeripheryImmutables is IPeripheryImmutables {
    address public override immutable factory;
    address public override immutable WETH10;

    constructor(address _factory, address _WETH10) {
        factory = _factory;
        WETH10 = _WETH10;
    }
}
