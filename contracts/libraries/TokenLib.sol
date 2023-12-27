// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

library TokenLib {
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1, bool order) {
        (token0, token1, order) = tokenA < tokenB
            ? (tokenA, tokenB, true)
            : (tokenB, tokenA, false);
    }
}
