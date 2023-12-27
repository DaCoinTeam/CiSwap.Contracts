// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IPeripheryPayments {
    function unwrapWETH10(
        uint amountMinimum,
        address recipient
    ) external payable;

    function refundETH() external payable;
}
