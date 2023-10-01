const hre = require("hardhat");

async function main() {
  const treasury = await hre.ethers.deployContract("Treasury", [
    "0xae13d989dac2f0debff460ac112a837c89baa7cd",
    "10000000000000000",
    "2592000",
    "300",
  ]);
  await treasury.waitForDeployment();

  console.log(treasury.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
