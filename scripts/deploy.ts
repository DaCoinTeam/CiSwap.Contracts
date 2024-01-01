import { ethers } from "hardhat"
import { extractAbi } from "./exact"

async function main() {
    await extractAbi()
    // const factory = await ethers.deployContract("Factory", [])
    // await factory.waitForDeployment()
    // const factoryAddress = await factory.getAddress()
    // console.log(`Factory ${factoryAddress}`)

    // const weth10 = await ethers.deployContract("WETH10", ["Wrapped KLAY", "WKLAY"])
    // await weth10.waitForDeployment()
    // const weth10Address = await weth10.getAddress()
    // console.log(`WETH10 ${weth10Address}`)

    // const router = await ethers.deployContract("Router", [factoryAddress, weth10Address])
    // await router.waitForDeployment()
    // const routerAddress = await router.getAddress()
    // console.log(`Router ${routerAddress}`)

    // const quoter = await ethers.deployContract("Quoter",  [factoryAddress, weth10Address])
    // await quoter.waitForDeployment()
    // const quoterAddress = await quoter.getAddress()
    // console.log(`Quoter ${quoterAddress}`)
    // // "0xCdA9529071c813f3E2220c20338f0EF015C4F2cf"
    // // export const KLAYTN_TESTNET_CONTRACT_WETH10 =
    // //   "0xc146A3b4691230248b340e6f26f1dA8d48073f26"
    const aggregator = await ethers.deployContract("Aggregator", ["0xE5F516A66a1E8cb6552B9fA4a6c69d193e061dC6", "0x39a836BC29E027552093713F8F287816B10DE8D9"])
    await aggregator.waitForDeployment()
    const aggregatorddress = await aggregator.getAddress()
    console.log(`Aggregator ${aggregatorddress}`)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})

//npx hardhat run --network baobap scripts/deploy.ts