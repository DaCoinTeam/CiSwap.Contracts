// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "solidity-bytes-utils/contracts/BytesLib.sol";
import "hardhat/console.sol";

library Path {
    using BytesLib for bytes;

    uint private constant ADDR_SIZE = 20;
    uint private constant INDEX_SIZE = 4;
    uint private constant NEXT_OFFSET = ADDR_SIZE + INDEX_SIZE;
    uint private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    uint private constant MULTIPLE_POOLS_MIN_LENGTH =
        POP_OFFSET + NEXT_OFFSET;

    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }

    function hasPool(bytes memory path) internal pure returns (bool) {
        return path.length >= POP_OFFSET;
    }

    function numPools(bytes memory path) internal pure returns (uint) {
        return ((path.length - ADDR_SIZE) / NEXT_OFFSET);
    }

    function decodeFirstPool(
        bytes memory path
    ) internal pure returns (address tokenA, address tokenB, uint32 index) {
        tokenA = path.toAddress(0);
        index = path.toUint32(ADDR_SIZE);
        tokenB = path.toAddress(NEXT_OFFSET);
    }

    function getFirstPool(
        bytes memory path
    ) internal pure returns (bytes memory) {
        return path.slice(0, POP_OFFSET);
    }

    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }
}
