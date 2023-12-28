import { HardhatUserConfig } from "hardhat/config"

import "@nomicfoundation/hardhat-toolbox"

import "hardhat-gas-reporter"
import "hardhat-contract-sizer"

import dotenv from "dotenv"
dotenv.config()

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.23",
        settings: {
            optimizer: {
                enabled: true,
                runs: 500,
            },
        },
    },
    networks: {
        baobap: {
            url: "https://api.baobab.klaytn.net:8651",
            chainId: 1001,
            accounts: {
                mnemonic: process.env.MNEMONIC,
            },
        },
    },
    gasReporter: {
        currency: "ETH",
        enabled: false,
        gasPrice: 25,
    },
    // mocha: {
    //     parallel: true
    // }
}

export default config
