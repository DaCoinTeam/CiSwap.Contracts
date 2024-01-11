import { expect } from "chai"
import { SetupResult, InitializeResult, initialize, setup } from "../utils"
import sqrt from "bigint-isqrt"

describe("test addliquidity", () => {
    let _initialize: InitializeResult
    let _setup: SetupResult
    before("initialize", async () => {
        _initialize = await initialize({
            tokens: [
                {
                    tokenName: "STARCI Token",
                    tokenSymbol: "STARCI",
                },
                {
                    tokenName: "USDT Token",
                    tokenSymbol: "USDT",
                },
            ],
        })
    })

    beforeEach("start", async () => {
        _setup = await setup(_initialize, {
            pools: [
                {
                    token0: {
                        address: _initialize.tokens[1].address,
                        amount: BigInt(10e19),
                    },
                    token1: {
                        address: _initialize.tokens[0].address,
                        amount: BigInt(0),
                    },
                    prices: {
                        base0X96: 0.5,
                        max0X96: 1,
                    },
                },
            ],
        })
    })

    it("should add successful", async () => {
        const pool = _setup.pools[0]
        // const slot0Before = await pool.contract.getFunction("slot0").staticCall()
        // const liquidityBefore = await pool.contract
        //     .getFunction("totalSupply")
        //     .staticCall()

        // await _initialize.tokens[1].contract
        //     .getFunction("transfer")
        //     .send(pool.address, BigInt(10e19))
        // const beforeSlot0 = await pool.contract.getFunction("slot0").staticCall()
        // const mitable = await pool.contract
        //     .getFunction("mint")
        //     .staticCall(_initialize.signers[0].address)
        // await pool.contract
        //     .getFunction("mint")
        //     .send(_initialize.signers[0].address)
        // const afterSlot0 = await pool.contract.getFunction("slot0").staticCall()
        // const rate = Number(
        //     sqrt(
        //         (BigInt(afterSlot0[0]) * BigInt(afterSlot0[1]) * BigInt(1000000)) /
        //   (BigInt(beforeSlot0[0]) * BigInt(beforeSlot0[1]))
        //     )
        // )
        // const compateRate = Number(
        //     ((mitable + liquidityBefore) * BigInt(1000)) / liquidityBefore
        // )
        // expect(rate).to.be.eq(compateRate)

        // const burn1 = await pool.contract
        //     .getFunction("burn")
        //     .staticCall(_initialize.signers[0].address, mitable)
        // expect(BigInt(10e19)).to.be.eq(BigInt(burn1[1]))
        // expect(BigInt(0)).to.be.eq(BigInt(burn1[0]))
        // await pool.contract
        //     .getFunction("burn")
        //     .send(_initialize.signers[0].address, mitable)

        // const slot0After = await pool.contract.getFunction("slot0").staticCall()
        // console.log(slot0After)
        // expect(sqrt(BigInt(slot0Before[0]) * BigInt(slot0Before[1]))).to.be.eq(
        //     sqrt(BigInt(slot0After[0]) * BigInt(slot0After[1]))
        // )
        //const price0X96 = await pool.contract.getFunction("price0X96").staticCall()
        await _initialize.tokens[1].contract
            .getFunction("approve")
            .send(_initialize.router.address, BigInt(10e25))
        await _initialize.tokens[0].contract
            .getFunction("approve")
            .send(_initialize.router.address, BigInt(10e25))

        const totalSupply = await pool.contract.getFunction("totalSupply").staticCall()
        console.log(totalSupply)
        const slot0 = await pool.contract.getFunction("slot0").staticCall()
    
        const lpPriceToken0 = slot0[0] * BigInt(100) / totalSupply
        const lpPriceToken1 = slot0[1] * BigInt(100) / totalSupply

        console.log(lpPriceToken0)
        console.log(lpPriceToken1)

        await _initialize.router.contract.getFunction("addLiquidity").send({
            tokenA: _initialize.tokens[0].address,
            tokenB: _initialize.tokens[1].address,
            indexPool: 0,
            amountA: BigInt(0),
            amountB: BigInt(10e25),
            amountMin: BigInt(0),
            recipient: _initialize.signers[0].address,
            deadline: BigInt(new Date().getTime()) / BigInt(1000) + BigInt(1000),
        })

        const totalSupplyX : bigint = await pool.contract.getFunction("totalSupply").staticCall()
    
        const slot0X = await pool.contract.getFunction("slot0").staticCall()

        const lpPriceToken0X = slot0X[0] * BigInt(100) / totalSupplyX
        const lpPriceToken1X = slot0X[1] * BigInt(100) / totalSupplyX

        console.log(lpPriceToken0X * BigInt(100) / totalSupplyX)
        console.log(lpPriceToken1X * BigInt(100) / totalSupplyX)
    
        expect(lpPriceToken0).to.be.eq(lpPriceToken0X)
        expect(lpPriceToken1).to.be.eq(lpPriceToken1X)
      
        await pool.contract
            .getFunction("approve") 
            
            .send(_initialize.router.address, BigInt(10e30))
        await _initialize.router.contract.getFunction("removeLiquidity").send({
            tokenA: _initialize.tokens[0].address,
            tokenB: _initialize.tokens[1].address,
            indexPool: BigInt(0),
            amount: BigInt("33087913295300943553"),
            amountAMin: BigInt(0),
            amountBMin: BigInt(0),
            recipient: _initialize.signers[0].address,
            deadline: BigInt(new Date().getTime()) / BigInt(1000) + BigInt(1000),
        })

        const totalSupplyY : bigint = await pool.contract.getFunction("totalSupply").staticCall()
    
        const slot0Y = await pool.contract.getFunction("slot0").staticCall()

        const lpPriceToken0Y = slot0Y[0] * BigInt(100) / totalSupplyY
        const lpPriceToken1Y = slot0Y[1] * BigInt(100) / totalSupplyY

        console.log(lpPriceToken0Y * BigInt(100) / totalSupplyY)
        console.log(lpPriceToken1Y * BigInt(100) / totalSupplyY)

        expect(lpPriceToken0Y).to.be.eq(lpPriceToken0X)
        expect(lpPriceToken1Y).to.be.eq(lpPriceToken1X)
    })
})
