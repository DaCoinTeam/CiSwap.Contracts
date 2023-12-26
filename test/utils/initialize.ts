import { ethers } from "hardhat"
import { BaseContract } from "ethers"
import { Address } from "web3"
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers"

export const initialize = async (
    params: InitializeParams
): Promise<InitializeResult> => {
    const signers = await ethers.getSigners()
    //WETH10
    const WETH10 = await ethers.getContractFactory("WETH10")
    const weth10 = await WETH10.deploy("Wrapped Ether 10", "WETH10")
    const weth10Address = await weth10.getAddress()

    //factory
    const Factory = await ethers.getContractFactory("Factory")
    const factory = await Factory.deploy()
    const factoryAddress = await factory.getAddress()

    //tokens
    const promises: Promise<void>[] = []
    const tokens: {
    contract: BaseContract;
    address: Address;
  }[] = []

    for (const token of params.tokens) {
        const promise = async () => {
            const ERC20 = await ethers.getContractFactory("ExtendERC20")
            const contract = await ERC20.deploy(token.tokenName, token.tokenSymbol)
            const address = await contract.getAddress()
            for (const signer of signers) {
                //large tokens for testing
                await contract.getFunction("mint").send(signer.address, BigInt(10e40))
            }

            tokens.push({
                address,
                contract,
            })
        }
        promises.push(promise())
    }

    await Promise.all(promises)
    return {
        signers,
        WETH10: {
            address: weth10Address,
            contract: weth10,
        },
        factory: {
            address: factoryAddress,
            contract: factory,
        },
        tokens,
    }
}

export interface InitializeParams {
  tokens: {
    tokenName: string;
    tokenSymbol: string;
  }[];
}

export interface InitializeResult {
  signers: HardhatEthersSigner[];
  WETH10: {
    contract: BaseContract;
    address: Address;
  };
  factory: {
    contract: BaseContract;
    address: Address;
  };
  tokens: {
    contract: BaseContract;
    address: Address;
  }[];
}
