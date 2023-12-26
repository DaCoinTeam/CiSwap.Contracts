// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IPoolState {
    function slot0()
        external
        returns (
            uint reserve0,
            uint reserve1,
            uint observationCardinality,
            bool unlocked
        );

    function observe(
        uint[] calldata secondAgos
    )
        external
        view
        returns (
            uint[] memory reserve0Cumulatives,
            uint[] memory reserve1Cumulatives
        );

    function observations(
        uint index
    )
        external
        returns (
            uint blockTimestamp,
            uint reserve0Cumulative,
            uint reserve1Cumulative
        );
}
