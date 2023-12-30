import { ethers } from "hardhat"
import { extractAbi } from "./exact"

async function main() {
    await extractAbi()
    const factory = await ethers.deployContract("Factory", [])
    await factory.waitForDeployment()
    const factoryAddress = await factory.getAddress()
    console.log(`Factory ${factoryAddress}`)

    const weth10 = await ethers.deployContract("WETH10", ["Wrapped KLAY", "WKLAY"])
    await weth10.waitForDeployment()
    const weth10Address = await weth10.getAddress()
    console.log(`WETH10 ${weth10Address}`)

    const router = await ethers.deployContract("Router", [factoryAddress, weth10Address])
    await router.waitForDeployment()
    const routerAddress = await router.getAddress()
    console.log(`Router ${routerAddress}`)

    const quoter = await ethers.deployContract("Quoter",  [factoryAddress, weth10Address])
    await quoter.waitForDeployment()
    const quoterAddress = await quoter.getAddress()
    console.log(`Quoter ${quoterAddress}`)

    const aggregator = await ethers.deployContract("Aggregator", [factoryAddress, weth10Address])
    await aggregator.waitForDeployment()
    const aggregatorddress = await aggregator.getAddress()
    console.log(`Aggregator ${aggregatorddress}`)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})

//npx hardhat run --network baobap scripts/deploy.ts