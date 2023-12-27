// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

abstract contract NoDelegateCall {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}
