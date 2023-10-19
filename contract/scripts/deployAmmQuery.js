const hre = require("hardhat");

async function main() {
  const ammQuery = await hre.ethers.deployContract("AMMQuery", []);
  await ammQuery.waitForDeployment();

  console.log(ammQuery.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
