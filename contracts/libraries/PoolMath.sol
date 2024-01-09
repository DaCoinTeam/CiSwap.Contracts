// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./ExtendMath.sol";

library PoolMath {
    using SafeCast for *;
    using Math for uint;
    using ExtendMath for uint;

    function _computeConstantA(
        uint priceABaseX96,
        uint priceAMaxX96,
        uint amountA
    ) private pure returns (uint) {
        uint priceRatioX96 = priceABaseX96.mulDiv(1 << 96, priceAMaxX96);

        uint sqrtPriceRatioX48 = priceRatioX96.sqrt();
        uint numerator = sqrtPriceRatioX48 * amountA;
        uint exponent = 1 << (96 / 2);
        (bool flag, uint denominator) = Math.trySub(
            exponent,
            sqrtPriceRatioX48
        );
        require(flag);
        return numerator / denominator;
    }

    function _computeConstantB(
        uint priceABaseX96,
        uint constantA,
        uint amountA,
        uint amountB
    ) private pure returns (uint) {
        uint denominator = 1 << 96;
        (bool flag, uint numerator) = Math.trySub(
            (amountA + constantA) * priceABaseX96,
            denominator * amountB
        );
        require(flag);
        return numerator / denominator;
    }

    function computeConstants(
        uint priceABaseX96,
        uint priceAMaxX96,
        uint amountA,
        uint amountB
    ) internal pure returns (uint constantA, uint constantB) {
        constantA = _computeConstantA(priceABaseX96, priceAMaxX96, amountA);
        constantB = _computeConstantB(
            priceABaseX96,
            constantA,
            amountA,
            amountB
        );
    }

    struct ComputeAmountOutParams {
        uint reserveIn;
        uint reserveOut;
        uint constantOut;
        uint amountIn;
        uint24 fee;
    }

    function computeAmountOut(
        ComputeAmountOutParams memory params
    ) internal pure returns (uint amountOut, uint feeAmount) {
        require(params.amountIn != 0);

        uint kLast = params.reserveIn * params.reserveOut;
        uint reserveInAdjusted = params.reserveIn + params.amountIn;
        uint reserveOutAdjusted = kLast.divRoundingUp(reserveInAdjusted);

        require(
            reserveOutAdjusted >= params.constantOut,
            "Insufficient amount out"
        );
        uint amountOutGross = params.reserveOut - reserveOutAdjusted;
        feeAmount = amountOutGross.computePercentageOf(params.fee);
        amountOut = amountOutGross - feeAmount;
    }

    struct ComputeAmountInParams {
        uint reserveIn;
        uint reserveOut;
        uint constantOut;
        uint amountOut;
        uint24 fee;
    }

    function computeAmountIn(
        ComputeAmountInParams memory params
    ) internal pure returns (uint amountIn, uint feeAmount) {
        require(params.amountOut != 0);

        uint amountOutGross = params.amountOut.computePartOf(10e4 - params.fee);
        feeAmount = amountOutGross - params.amountOut;

        uint kLast = params.reserveIn * params.reserveOut;
        uint reserveOutAdjusted = params.reserveOut - amountOutGross;

        require(reserveOutAdjusted >= params.constantOut);
        uint reserveInAdjusted = kLast.divRoundingUp(reserveOutAdjusted);
        amountIn = reserveInAdjusted - params.reserveIn;
    }

    function computeLiquidity(
        uint reserve0,
        uint reserve1
    ) internal pure returns (uint) {
        return (reserve0 * reserve1).sqrt();
    }

    function computePriceX96(
        uint reserve0,
        uint reserve1,
        uint24 fee,
        bool zeroForOne
    ) internal pure returns (uint) {
        return
            zeroForOne
                ? reserve1.mulDiv(1 << 96, reserve0).computePercentageOf(
                    10e4 - fee
                )
                : reserve0.mulDiv(1 << 96, reserve1).computePercentageOf(
                    10e4 - fee
                );
    }

    function hasLiquidityGrownAfterFees(
        uint reserve0Before,
        uint reserve1Before,
        uint reserve0After,
        uint reserve1After,
        uint24 fee
    ) internal pure returns (bool) {
        uint liquidityBefore = PoolMath.computeLiquidity(
            reserve0Before,
            reserve1Before
        );
        uint liquidityAfterGross = PoolMath.computeLiquidity(
            reserve0After,
            reserve1After
        );
        uint liquidityAfter = liquidityAfterGross.computePercentageOf(
            10e4 - fee
        );
        return liquidityAfter >= liquidityBefore;
    }

    struct MintAmountsAndConstantIncrements {
        uint amount;
        uint amountLock;
        uint constant0Increment;
        uint constant1Increment;
    }

    function computeMintAmountsAndConstantIncrements(
        uint totalSupply,
        uint reserve0Before,
        uint reserve1Before,
        uint reserve0After,
        uint reserve1After
    )
        internal
        pure
        returns (
            MintAmountsAndConstantIncrements memory result
        )
    {
        uint liquidityBefore = PoolMath.computeLiquidity(
            reserve0Before,
            reserve1Before
        );
        uint liquidityAfter = PoolMath.computeLiquidity(
            reserve0After,
            reserve1After
        );
        require(liquidityAfter > liquidityBefore);
        result.amount = (liquidityAfter - liquidityBefore).mulDiv(
            totalSupply,
            liquidityBefore
        );
        uint ratioX96Before = reserve0Before.mulDiv(1 << 96, reserve1Before);
        uint ratioX96After = (reserve0After).mulDiv(1 << 96, reserve1After);

        uint reserve0Last = reserve0After;
        uint reserve1Last = reserve1After;

        if (ratioX96Before < ratioX96After) {
            result.constant1Increment =
                (reserve0After * reserve1Before).divRoundingUp(reserve0Before) -
                reserve1After;
            reserve1Last += result.constant1Increment;
        }
        if (ratioX96Before > ratioX96After) {
            result.constant0Increment =
                (reserve1After * reserve0Before).divRoundingUp(reserve1Before) -
                reserve0After;
            reserve0Last += result.constant0Increment;
        }

        // compute liquidity deltas
        uint liquidityLast = PoolMath.computeLiquidity(
            reserve0Last,
            reserve1Last
        );
        result.amountLock = (liquidityLast - liquidityAfter).mulDivRoundingUp(
            totalSupply,
            liquidityAfter
        );
    }

    struct BurnAmountsAndConstantDecrements {
        uint amount0;
        uint amount1;
        uint amountLock;
        uint constant0Decrement;
        uint constant1Decrement;
    }

    function computeBurnAmountsAndConstantDecrements(
        uint amount,
        uint totalSupply,
        uint reserve0,
        uint reserve1,
        uint balance0Net,
        uint balance1Net
    ) internal pure returns (BurnAmountsAndConstantDecrements memory result) {
        result.amount0 = reserve0.mulDiv(amount, totalSupply);
        result.amount1 = reserve1.mulDiv(amount, totalSupply);
        uint kLast = (reserve0 - result.amount0) * (reserve1 - result.amount1);

        if (result.amount0 > balance0Net) {
            result.amount0 = balance0Net;
            uint reserve1Adjusted = kLast.divRoundingUp(
                reserve0 - result.amount0
            );
            result.amount1 = reserve1 - reserve1Adjusted;
        } else if (result.amount1 > balance1Net) {
            result.amount1 = balance1Net;
            uint reserve0Adjusted = kLast.divRoundingUp(
                reserve1 - result.amount1
            );
            result.amount0 = reserve0 - reserve0Adjusted;
        }

        uint reserve0After = reserve0 - result.amount0;
        uint reserve1After = reserve1 - result.amount1;

        uint ratioX96Before = reserve0.mulDiv(1 << 96, reserve1);
        uint ratioX96After = (reserve0After).mulDiv(1 << 96, reserve1After);

        uint reserve0Last = reserve0After;
        uint reserve1Last = reserve1After;

        if (ratioX96Before < ratioX96After) {
            result.constant0Decrement =
                reserve0After -
                (reserve0 * reserve1After).divRoundingUp(reserve1);
            reserve0Last -= result.constant0Decrement;
        }
        if (ratioX96Before > ratioX96After) {
            result.constant1Decrement =
                reserve1After -
                (reserve1 * reserve0After).divRoundingUp(reserve0);
            reserve1Last -= result.constant1Decrement;
        }

        // compute liquidity deltas
        uint liquidityAfter = PoolMath.computeLiquidity(
            reserve0After,
            reserve1After
        );
        uint liquidityLast = PoolMath.computeLiquidity(
            reserve0Last,
            reserve1Last
        );
        result.amountLock = (liquidityAfter - liquidityLast).mulDiv(
            totalSupply,
            liquidityAfter
        );
    }
}
