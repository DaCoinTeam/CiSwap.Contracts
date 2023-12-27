// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IPeripheryImmutables {
    function factory() external view returns (address);

    function WETH10() external view returns (address);
}
