import { expect } from "chai"
import { SetupResult, InitializeResult, initialize, setup } from "../utils"

describe("test create pool", () => {
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
                        amount: BigInt(10e19),
                    },
                    prices: {
                        base0X96: 0.5,
                        max0X96: 1,
                    },
                },
            ],
        })
    })

    it("should pool create successful", async () => {
        const pool = _setup.pools[0]
        const slot0 = await pool.contract.getFunction("slot0").staticCall()
        const token0 = await pool.contract.getFunction("token0").staticCall()
        const token1 = await pool.contract.getFunction("token1").staticCall()
        //const a = (await pool.contract.getFunction("price0X96").staticCall()) * BigInt(1000) >> BigInt(96)
        expect(
            Number(token0 < token1
                ? (slot0.reserve1 * BigInt(1000)) / slot0.reserve0
                : (slot0.reserve0 * BigInt(1000)) / slot0.reserve1)
        ).to.be.approximately(500, 1)
    })
})
