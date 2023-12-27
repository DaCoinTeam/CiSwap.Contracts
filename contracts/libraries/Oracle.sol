// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "hardhat/console.sol";

library Oracle {
    using Math for uint;

    struct Observation {
        uint blockTimestamp;
        uint reserve0Cumulative;
        uint reserve1Cumulative;
    }

    function _transform(
        Observation memory last,
        uint blockTimestamp,
        uint reserve0,
        uint reserve1
    ) private pure returns (Observation memory) {
        uint delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                reserve0Cumulative: last.reserve0Cumulative + reserve0 * delta,
                reserve1Cumulative: last.reserve1Cumulative + reserve1 * delta
            });
    }

    function initialize(
        Observation[] storage self,
        uint time
    ) internal returns (uint cardinality) {
        self.push(
            Observation({
                blockTimestamp: time,
                reserve0Cumulative: 0,
                reserve1Cumulative: 0
            })
        );
        return 1;
    }

    function write(
        Observation[] storage self,
        uint cardinality,
        uint time,
        uint reserve0,
        uint reserve1
    ) internal returns (uint cardinalityUpdated) {
        Observation memory last = self[cardinality - 1];
        if (time == last.blockTimestamp) {
            self[cardinality - 1] = _transform(last, time, reserve0, reserve1);
            return cardinality;
        }
        self.push(_transform(last, time, reserve0, reserve1));
        return cardinality + 1;
    }

    function _binarySearch(
        Observation[] memory observations,
        uint target,
        uint cardinality
    )
        private
        pure
        returns (Observation memory beforeOrAt, Observation memory atOrAfter)
    {
        require(observations.length >= 2);

        Observation memory first = observations[0];
        Observation memory last = observations[cardinality - 1];

        if (target >= last.blockTimestamp) return (last, last);

        if (target >= first.blockTimestamp) {
            uint l = 0;
            uint r = cardinality - 1;

            uint i;

            while (true) {
                i = Math.average(l, r);

                beforeOrAt = observations[i];
                if (beforeOrAt.blockTimestamp > target) {
                    r = i - 1;
                    continue;
                }

                atOrAfter = observations[i + 1];
                if (atOrAfter.blockTimestamp <= target) {
                    l = i + 1;
                    continue;
                }
                break;
            }
        }
    }

    function _interpolate(
        Observation memory beforeOrAt,
        Observation memory atOrAfter,
        uint target
    ) private pure returns (Observation memory) {
        require(
            beforeOrAt.blockTimestamp <= target &&
                target < atOrAfter.blockTimestamp
        );
        uint delta = target - beforeOrAt.blockTimestamp;
        uint entire = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
        return
            Observation({
                blockTimestamp: target,
                reserve0Cumulative: beforeOrAt.reserve0Cumulative +
                    (atOrAfter.reserve0Cumulative -
                        beforeOrAt.reserve0Cumulative).mulDiv(delta, entire),
                reserve1Cumulative: beforeOrAt.reserve1Cumulative +
                    (atOrAfter.reserve1Cumulative -
                        beforeOrAt.reserve1Cumulative).mulDiv(delta, entire)
            });
    }

    function _observeSingle(
        Observation[] memory observations,
        uint time,
        uint reserve0,
        uint reserve1,
        uint cardinality,
        uint secondAgo
    ) private pure returns (uint reserve0Cumulative, uint reserve1Cumulative) {
        uint target = time - secondAgo;
        (
            Observation memory beforeOrAt,
            Observation memory atOrAfter
        ) = _binarySearch(observations, target, cardinality);
        if (beforeOrAt.blockTimestamp == atOrAfter.blockTimestamp) {
            if (atOrAfter.blockTimestamp != 0) {
                atOrAfter = _transform(atOrAfter, time, reserve0, reserve1);
            }
            return (atOrAfter.reserve0Cumulative, atOrAfter.reserve1Cumulative);
        }

        Observation memory interpolate = _interpolate(
            beforeOrAt,
            atOrAfter,
            target
        );
        return (interpolate.reserve0Cumulative, interpolate.reserve1Cumulative);
    }

    function observe(
        Observation[] storage self,
        uint time,
        uint reserve0,
        uint reserve1,
        uint cardinality,
        uint[] memory secondAgos
    )
        internal
        pure
        returns (
            uint[] memory reserve0Cumulatives,
            uint[] memory reserve1Cumulatives
        )
    {
        uint length = secondAgos.length;
        reserve0Cumulatives = new uint[](length);
        reserve1Cumulatives = new uint[](length);

        Observation[] memory _observations = self;

        for (uint i = 0; i < length; i++) {
            (reserve0Cumulatives[i], reserve1Cumulatives[i]) = _observeSingle(
                _observations,
                time,
                reserve0,
                reserve1,
                cardinality,
                secondAgos[i]
            );
        }
    }
}
