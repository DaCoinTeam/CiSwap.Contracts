// import { expect } from "chai"
// import { SetupResult, InitializeResult, initialize, setup } from "../utils"

// describe("test swap", () => {
//     let _initialize: InitializeResult
//     let _setup: SetupResult
//     before("initialize", async () => {
//         _initialize = await initialize({
//             tokens: [
//                 {
//                     tokenName: "STARCI Token",
//                     tokenSymbol: "STARCI",
//                 },
//                 {
//                     tokenName: "USDT Token",
//                     tokenSymbol: "USDT",
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
//             ],
//         })
//     })

//     it("should swap successful", async () => {
//         const pool = _setup.pools[0]
//         //revert due to no input
//         await expect(
//             pool.contract.getFunction("swap").send({
//                 amountSpecified: BigInt(10e4),
//                 limitAmountCalculated: BigInt(0),
//                 zeroForOne: false,
//                 recipient: _initialize.signers[0].address,
//                 callback: "0x",
//             })
//         ).to.be.rejectedWith("Insufficient input")

//         await _initialize.tokens[0].contract
//             .getFunction("transfer")
//             .send(pool.address, BigInt(10e4))
//         const price1 =
//       ((await pool.contract.getFunction("price1X96").staticCall()) *
//         BigInt(1000)) >>
//       BigInt(96)
//         const calldata = await pool.contract.getFunction("swap").staticCall({
//             amountSpecified: BigInt(10e4),
//             limitAmountCalculated: BigInt(0),
//             zeroForOne: false,
//             recipient: _initialize.signers[0].address,
//             callback: "0x",
//         })
//         // compute price receive or in base on price1X96
//         expect(calldata[1]).to.be.eq(BigInt(-10e4))
//         expect(calldata[0]).to.be.eq((BigInt(10e4) * price1) / BigInt(1000))

//         await pool.contract.getFunction("swap").send({
//             amountSpecified: BigInt(10e4),
//             limitAmountCalculated: BigInt(0),
//             zeroForOne: false,
//             recipient: _initialize.signers[0].address,
//             callback: "0x",
//         })

//         // check whether trade fee is added
//         const slot0 = await pool.contract.getFunction("slot0").staticCall()
//         expect(slot0[4]).to.be.eq(BigInt(999))

//         await _initialize.tokens[0].contract
//             .getFunction("transfer")
//             .send(pool.address, BigInt(10e4))

//         await pool.contract.getFunction("swap").send({
//             amountSpecified: BigInt(10e4),
//             limitAmountCalculated: BigInt(0),
//             zeroForOne: false,
//             recipient: _initialize.signers[0].address,
//             callback: "0x",
//         })
//         //changes
//         const slot02 = await pool.contract.getFunction("slot0").staticCall()
//         console.log(slot02)
//         expect(slot02[4]).to.be.eq(BigInt(1998))
//     })
//     it("should fee work corret", async () => {
//         const pool = _setup.pools[0]
//         for (let i = 0; i < 15; i++) {
//             await _initialize.tokens[0].contract
//                 .getFunction("transfer")
//                 .send(pool.address, BigInt(10e17))
//             await pool.contract.getFunction("swap").send({
//                 amountSpecified: BigInt(10e17),
//                 limitAmountCalculated: BigInt(0),
//                 zeroForOne: false,
//                 recipient: _initialize.signers[0].address,
//                 callback: "0x",
//             })
//             console.log("call")
//         }

//         const slot0 = await pool.contract.getFunction("slot0").staticCall()
//         console.log(slot0)
//         const constant0 = await pool.contract.getFunction("constant0").staticCall()
//         const balance0 = await _initialize.tokens[1].contract
//             .getFunction("balanceOf")
//             .staticCall(pool.address)
//         console.log(BigInt(balance0) + BigInt(constant0))
//         expect(BigInt(slot0[4]) + BigInt(slot0[0])).to.be.eq(
//             BigInt(balance0) + BigInt(constant0)
//         )
//     })
// })
