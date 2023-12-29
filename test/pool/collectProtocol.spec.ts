import { expect } from "chai"
import { SetupResult, InitializeResult, initialize, setup } from "../utils"

describe("collect Protocol", () => {
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

    it("should collect protocol", async () => {
        const pool = _setup.pools[0]
        for (let i = 0; i < 15; i++) {
            await _initialize.tokens[0].contract
                .getFunction("transfer")
                .send(pool.address, BigInt(10e19))
            await _initialize.tokens[1].contract
                .getFunction("transfer")
                .send(pool.address, BigInt(10e19))
            await pool.contract.getFunction("swap").send({
                amountSpecified: i % 2 ? BigInt(10e17) : BigInt(10e18),
                limitAmountCalculated: BigInt(0),
                zeroForOne: i % 2,
                recipient: _initialize.signers[0].address,
                callback: "0x",
            })
        }
        const balance0Before =await  _initialize.tokens[0].contract.getFunction("balanceOf").staticCall(_initialize.signers[1].address)
        const res = await pool.contract.getFunction("collectProtocol").staticCall(_initialize.signers[1].address, BigInt("9999999999999999999999999999999"), BigInt("9999999999999999999999999999999"))
        await pool.contract.getFunction("collectProtocol").send(_initialize.signers[1].address, BigInt("9999999999999999999999999999999"), BigInt("9999999999999999999999999999999"))
        // const slot0 = await pool.contract.getFunction("slot0").staticCall()
        const balance0After = await _initialize.tokens[0].contract.getFunction("balanceOf").staticCall(_initialize.signers[1].address)
        expect(BigInt(balance0After) - BigInt(balance0Before)).to.be.eq(res[0])
    })
})
