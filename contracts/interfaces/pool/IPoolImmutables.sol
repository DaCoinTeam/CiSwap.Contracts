// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IPoolImmutables {
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);

    function indexPool() external view returns (uint32);

    function config()
        external
        view
        returns (
            address tokenA,
            address tokenB,
            uint amountA,
            uint amountB,
            uint basePrice,
            uint maxPriceA
        );
}
