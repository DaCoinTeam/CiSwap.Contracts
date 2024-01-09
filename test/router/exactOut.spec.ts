// import { expect } from "chai"
// import { SetupResult, InitializeResult, initialize, setup } from "../utils"
// import { ethers } from "hardhat"
// import { time } from "@nomicfoundation/hardhat-network-helpers"

// describe("test router", () => {
//     let _initialize: InitializeResult
//     let _setup: SetupResult
//     before("initialize", async () => {
//         _initialize = await initialize({
//             tokens: [
//                 {
//                     tokenName: "Kahlii Token",
//                     tokenSymbol: "Kahlii",
//                 },
//                 {
//                     tokenName: "Krixi Token",
//                     tokenSymbol: "Krixi",
//                 },
//                 {
//                     tokenName: "Toro Token",
//                     tokenSymbol: "Toro",
//                 },
//                 {
//                     tokenName: "Gildur Token",
//                     tokenSymbol: "Gildur",
//                 },
//                 {
//                     tokenName: "Mganga Token",
//                     tokenSymbol: "Mganga",
//                 },
//             ],
//         })
//     })

//     beforeEach("start", async () => {
//         _setup = await setup(_initialize, {
//             pools: [
//                 {
//                     token0: {
//                         address: _initialize.tokens[1].address,
//                         amount: BigInt(10e19),
//                     },
//                     token1: {
//                         address: _initialize.tokens[0].address,
//                         amount: BigInt(0),
//                     },
//                     prices: {
//                         base0X96: 0.5,
//                         max0X96: 1,
//                     },
//                 },
//                 {
//                     token0: {
//                         address: _initialize.tokens[2].address,
//                         amount: BigInt(10e19),
//                     },
//                     token1: {
//                         address: _initialize.tokens[1].address,
//                         amount: BigInt(10e19),
//                     },
//                     prices: {
//                         base0X96: 0.5,
//                         max0X96: 1,
//                     },
//                 },
//                 {
//                     token0: {
//                         address: _initialize.tokens[3].address,
//                         amount: BigInt(10e19),
//                     },
//                     token1: {
//                         address: _initialize.tokens[2].address,
//                         amount: BigInt(10e19),
//                     },
//                     prices: {
//                         base0X96: 0.5,
//                         max0X96: 1,
//                     },
//                 },
//                 {
//                     token0: {
//                         address: _initialize.tokens[4].address,
//                         amount: BigInt(10e19),
//                     },
//                     token1: {
//                         address: _initialize.tokens[3].address,
//                         amount: BigInt(10e19),
//                     },
//                     prices: {
//                         base0X96: 0.5,
//                         max0X96: 1,
//                     },
//                 },
//             ],
//         })
//     })

//     it("should exact output successful", async () => {
//         await _initialize.tokens[0].contract
//             .getFunction("approve")
//             .send(_initialize.router.address, BigInt(10e20))
//         // for (let i = 0; i < 20; i++) {
//         //     await time.increase(30 * 60)
//         //     await _initialize.router.contract.getFunction("exactOutput").send({
//         //         amountOut: BigInt(10e17),
//         //         amountInMax: BigInt(10e19),
//         //         recipient: _initialize.signers[0].address,
//         //         path: ethers.solidityPacked(
//         //             [
//         //                 "address",
//         //                 "uint32",
//         //                 "address",
//         //                 "uint32",
//         //                 "address"
//         //             ],
//         //             [
//         //                 _initialize.tokens[0].address,
//         //                 0,
//         //                 _initialize.tokens[1].address,
//         //                 0,
//         //                 _initialize.tokens[2].address
//         //             ]
//         //         ),
//         //         deadline:
//         //   BigInt(Date.now()) / BigInt(1000) + BigInt(60 * 60 * 24 * 2 * 60),
//         //     })
//         // }
//         await _initialize.router.contract
//             .getFunction("exactOutputSingle")
//             .send({
//                 amountOut: BigInt(10e17),
//                 amountInMax: BigInt(10e19),
//                 recipient: _initialize.signers[0].address,
//                 tokenIn: _initialize.tokens[0].address,
//                 tokenOut: _initialize.tokens[1].address,
//                 indexPool: 0,
//                 deadline:
//           BigInt(Date.now()) / BigInt(1000) + BigInt(60 * 60 * 24 * 2 * 60),
//             })

//         // await time.increase(60 * 60 * 24)
//         // const values = await _initialize.oracleAggregator.contract
//         //     .getFunction("aggregatePriceX96")
//         //     .staticCall(
//         //         BigInt(60 * 60),
//         //         10,
//         //         ethers.solidityPacked(
//         //             [
//         //                 "address",
//         //                 "uint32",
//         //                 "address",
//         //                 "uint32",
//         //                 "address"
//         //             ],
//         //             [
//         //                 _initialize.tokens[0].address,
//         //                 0,
//         //                 _initialize.tokens[1].address,
//         //                 0,
//         //                 _initialize.tokens[2].address,
//         //             ]
//         //         )
//         //     )
//         // console.log(values.map((value) => (value * BigInt(1000)) >> BigInt(96)))

//         //     const values2 = await _initialize.oracleAggregator.contract
//         //         .getFunction("aggregateLiquidity")
//         //         .staticCall(
//         //             BigInt(60 * 60),
//         //             BigInt(7),
//         //             _initialize.tokens[0].address,
//         //             _initialize.tokens[1].address,
//         //             0
//         //         )
//         //     console.log(values2)

//     //     // test next price
//     //     time.increase(24 * 60 * 60)
//     //     await _initialize.router.contract.getFunction("exactOutput").send({
//     //         amountOut: BigInt(10e14),
//     //         amountInMax: BigInt(10e19),
//     //         recipient: _initialize.signers[0].address,
//     //         path: ethers.solidityPacked(
//     //             [
//     //                 "address",
//     //                 "uint32",
//     //                 "address"
//     //             ],
//     //             [
//     //                 _initialize.tokens[0].address,
//     //                 0,
//     //                 _initialize.tokens[1].address
//     //             ]
//     //         ),
//     //         deadline:
//     //     BigInt(Date.now()) / BigInt(1000) + BigInt(60 * 60 * 24 * 2 * 60),
//     //     })
//     })
// })
