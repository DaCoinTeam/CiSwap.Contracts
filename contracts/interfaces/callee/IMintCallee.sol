// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IMintCallee {
    function mintCall(
        bytes calldata callback
    ) external;
}
