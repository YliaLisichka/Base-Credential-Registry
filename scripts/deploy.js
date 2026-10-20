const hre = require("hardhat");
async function main() {
  const RegistryData = await hre.ethers.getContractFactory("NovaCredentialRegistry");
  const novaRegistry = await RegistryData.deploy();
  await novaRegistry.deployed();
  console.log("-> Credentials Core active at:", novaRegistry.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
