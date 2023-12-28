// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IAggregator {
    function aggregatePriceX96(
        uint secondOffset,
        uint16 numberOfSnapshots,
        bytes memory path
    ) external view returns (uint[] memory priceX96s);

    function aggregateLiquidity(
        uint secondOffset,
        uint16 numberOfSnapshots,
        address tokenA,
        address tokenB,
        uint32 indexPool
    ) external view returns (uint[] memory liquidities);
}
