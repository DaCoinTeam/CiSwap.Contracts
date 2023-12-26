import { Address } from "web3"
import { InitializeResult } from "./initialize"
import { BaseContract } from "ethers"
import { ethers } from "hardhat"

export const setup = async (
    initialize: InitializeResult,
    params: SetupParams
): Promise<SetupResult> => {
    const pools: {
    contract: BaseContract;
    address: Address;
  }[] = []
    for (let i = 0; i < params.pools.length; i++) {
        const pool = params.pools[i]
        const token0 = await ethers.getContractAt(
            "ExtendERC20",
            pool.token0.address
        )
        const token1 = await ethers.getContractAt(
            "ExtendERC20",
            pool.token1.address
        )

        //max aprrove
        await token0
            .getFunction("approve")
            .send(initialize.factory.address, BigInt(10e40))
        await token1
            .getFunction("approve")
            .send(initialize.factory.address, BigInt(10e40))

        const createPoolResponse = await initialize.factory.contract
            .getFunction("createPool")
            .send({
                fee: 2500,
                config: {
                    tokenA: pool.token0.address,
                    tokenB: pool.token1.address,
                    amountA: pool.token0.amount,
                    amountB: pool.token1.amount,
                    basePriceAX96:
            BigInt((pool.prices.base0X96 * 1000).toFixed()) *
            (BigInt(1) << BigInt(96)) / BigInt(1000),
                    maxPriceAX96:
            BigInt((pool.prices.max0X96 * 1000).toFixed()) *
            (BigInt(1) << BigInt(96))  / BigInt(1000),
                },
            })
        const createPoolReceipt = await createPoolResponse.wait()
        const poolAddress = createPoolReceipt?.logs[0].address as Address
        const poolContract = await ethers.getContractAt("Pool", poolAddress)

        pools.push({
            address: poolAddress,
            contract: poolContract,
        })
    }

    return {
        pools,
    }
}

export interface SetupParams {
  pools: {
    token0: {
      address: Address;
      amount: bigint;
    };
    token1: {
      address: Address;
      amount: bigint;
    };
    prices: {
      base0X96: number;
      max0X96: number;
    };
  }[];
}

export interface SetupResult {
  pools: {
    contract: BaseContract;
    address: Address;
  }[];
}
