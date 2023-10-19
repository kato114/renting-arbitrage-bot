const hre = require("hardhat");

async function main() {
  const arbitrage = await hre.ethers.deployContract("Arbitrage", []);
  await arbitrage.waitForDeployment();

  console.log(arbitrage.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
