// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./interfaces/IAggregator.sol";
import "./base/PeripheryPoolManagement.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./libraries/Path.sol";
import "./interfaces/pool/IPool.sol";
import "./libraries/PoolMath.sol";

contract Aggregator is IAggregator, Context, PeripheryPoolManagement {
    using Path for bytes;
    using Math for uint256;

    constructor(
        address _factory,
        address _WETH10
    ) PeripheryImmutables(_factory, _WETH10) {}

    function _getReserves(
        address pool,
        uint secondOffset,
        uint16 i
    ) private view returns (bool exist, uint reserve0, uint reserve1) {
        require(i > 0);
        uint[] memory observeParams = new uint[](2);
        (observeParams[0], observeParams[1]) = (
            (i - 1) * secondOffset,
            (i + 1) * secondOffset
        );
        (
            uint[] memory reserve0Cumulatives,
            uint[] memory reserve1Cumulatives
        ) = IPool(pool).observe(observeParams);
        console.log("test %s", reserve0Cumulatives[0]);
         console.log("test %s", reserve0Cumulatives[1]);
        exist = reserve0Cumulatives[0] > 0 || reserve1Cumulatives[0] > 0;

        if (exist) {
            uint timeDelta = 2 * secondOffset;
            reserve0 =
                (reserve0Cumulatives[0] - reserve0Cumulatives[1]) /
                timeDelta;
            reserve1 =
                (reserve1Cumulatives[0] - reserve1Cumulatives[1]) /
                timeDelta;
        }
    }

    struct AggregatePriceX96Current {
        address tokenIn;
        address tokenOut;
        uint32 indexPool;
        bool zeroForOne;
        address pool;
        uint24 fee;
    }

    function aggregatePriceX96(
        uint secondOffset,
        uint16 numberOfSnapshots,
        bytes memory path
    ) external view override returns (uint[] memory priceX96s) {
        priceX96s = new uint[](numberOfSnapshots);
        bool first = true;
        AggregatePriceX96Current memory current;
        while (true) {
            if (path.hasPool()) {
                (current.tokenIn, current.tokenOut, current.indexPool) = path
                    .decodeFirstPool();
                current.zeroForOne = current.tokenIn < current.tokenOut;

                current.pool = _getPool(
                    current.tokenIn,
                    current.tokenOut,
                    current.indexPool
                );
                current.fee = IPool(current.pool).fee();

                for (uint16 i = 0; i < numberOfSnapshots; i++) {
                    if (first) {
                        priceX96s[i] = 1 << 96;
                    }
                    if (i == 0) {
                        priceX96s[i] = priceX96s[i].mulDiv(
                            (
                                current.zeroForOne
                                    ? IPool(current.pool).price0X96()
                                    : IPool(current.pool).price1X96()
                            ),
                            1 << 96
                        );
                    } else {
                        (
                            bool exist,
                            uint reserve0,
                            uint reserve1
                        ) = _getReserves(current.pool, secondOffset, i);

                        if (!exist) {
                            priceX96s[i] = 0;
                            break;
                        }

                        priceX96s[i] = priceX96s[i].mulDiv(
                            PoolMath.computePriceX96(
                                reserve0,
                                reserve1,
                                current.fee,
                                current.zeroForOne
                            ),
                            1 << 96
                        );
                    }
                }
                first = false;
                path = path.skipToken();
                continue;
            }
            break;
        }
    }

    function aggregateLiquidity(
        uint secondOffset,
        uint16 numberOfSnapshots,
        address tokenA,
        address tokenB,
        uint32 indexPool
    ) external view override returns (uint[] memory liquidities) {
        liquidities = new uint[](numberOfSnapshots);

        for (uint16 i = 0; i < numberOfSnapshots; i++) {
            address pool = _getPool(tokenA, tokenB, indexPool);
            if (i == 0) {
                liquidities[0] = IPool(pool).liquidity();
                continue;
            }
            (bool exist, uint reserve0, uint reserve1) = _getReserves(
                pool,
                secondOffset,
                i
            );
            liquidities[i] = exist
                ? PoolMath.computeLiquidity(reserve0, reserve1)
                : 0;
        }
    }
}
