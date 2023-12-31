// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./IPoolActions.sol";
import "./IPoolEvents.sol";
import "./IPoolImmutables.sol";
import "./IPoolState.sol";

interface IPool is IPoolActions, IPoolEvents, IPoolImmutables, IPoolState {}
