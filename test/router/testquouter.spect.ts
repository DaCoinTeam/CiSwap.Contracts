import { expect } from "chai"
import { SetupResult, InitializeResult, initialize, setup } from "../utils"
import { ethers } from "hardhat"
import { time } from "@nomicfoundation/hardhat-network-helpers"

describe("test quoteExactOutput", () => {
    let _initialize: InitializeResult
    let _setup: SetupResult
    before("initialize", async () => {
        _initialize = await initialize({
            tokens: [
                {
                    tokenName: "Kahlii Token",
                    tokenSymbol: "Kahlii",
                },
                {
                    tokenName: "Krixi Token",
                    tokenSymbol: "Krixi",
                },
                {
                    tokenName: "Toro Token",
                    tokenSymbol: "Toro",
                },
                {
                    tokenName: "Gildur Token",
                    tokenSymbol: "Gildur",
                },
                {
                    tokenName: "Mganga Token",
                    tokenSymbol: "Mganga",
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
                {
                    token0: {
                        address: _initialize.tokens[2].address,
                        amount: BigInt(10e19),
                    },
                    token1: {
                        address: _initialize.tokens[1].address,
                        amount: BigInt(10e19),
                    },
                    prices: {
                        base0X96: 0.5,
                        max0X96: 1,
                    },
                },
                {
                    token0: {
                        address: _initialize.tokens[3].address,
                        amount: BigInt(10e19),
                    },
                    token1: {
                        address: _initialize.tokens[2].address,
                        amount: BigInt(10e19),
                    },
                    prices: {
                        base0X96: 0.5,
                        max0X96: 1,
                    },
                },
                {
                    token0: {
                        address: _initialize.tokens[4].address,
                        amount: BigInt(10e19),
                    },
                    token1: {
                        address: _initialize.tokens[3].address,
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

    it("should exact qouter successful", async () => {
        console.log(
            await _initialize.quoter.contract
                .getFunction("quoteExactOutput")
                .staticCall(
                    ethers.solidityPacked(
                        ["address", "uint32", "address"],
                        [
                            _initialize.tokens[0].address,
                            0,
                            _initialize.tokens[1].address
                        ]
                    ),
                    BigInt(10e20)
                )
        )
    })
})