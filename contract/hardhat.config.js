require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "bscTestNet",
  networks: {
    bscMainNet: {
      url: "https://bsc-dataseed.binance.org",
      accounts: [process.env.BSCMainNet],
    },
    bscTestNet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: [process.env.BSCTestNet],
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.1",
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
  etherscan: {
    apiKey: {
      bscMainNet: "WHT4G5RK1PKC439WKJICI4G8F51DWUQGYK",
      bscTestnet: "WHT4G5RK1PKC439WKJICI4G8F51DWUQGYK",
    },
  },
};
