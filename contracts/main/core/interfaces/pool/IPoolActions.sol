// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IPoolActions {
    struct SwapParams {
        int amountSpecified;
        uint limitAmountCalculated;
        bool zeroForOne;
        address recipient;
        bytes callback;
    }

    function initialize() external;

    function swap(
        SwapParams calldata params
    ) external returns (int256 amount0, int256 amount1);

    function mint(
        address recipient
    ) external returns (uint amount, uint feeToOwner);

    function burn(
        address recipient,
        uint amount
    ) external returns (uint amount0, uint amount1);

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata callback
    ) external returns (uint paid0, uint paid1);
}
