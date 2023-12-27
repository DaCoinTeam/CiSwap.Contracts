// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

library ExtendMath {
    using SafeCast for *;
    using Math for uint256;

    function mulDivRoundingUp(
        uint a,
        uint b,
        uint denominator
    ) internal pure returns (uint result) {
        result = a.mulDiv(b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            result++;
        }
    }

    function divRoundingUp(uint a, uint b) internal pure returns (uint result) {
        result = a / b;
        if (a % b > 0) {
            result++;
        }
    }

    function computePercentageOf(
        uint x,
        uint24 percentage
    ) internal pure returns (uint) {
        return x.mulDiv(percentage, 10e4);
    }

    function computePartOf(
        uint x,
        uint24 percentage
    ) internal pure returns (uint) {
        return mulDivRoundingUp(x, 10e4, percentage);
    }
}
