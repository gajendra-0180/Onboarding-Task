// import { HardhatUserConfig } from "hardhat/config";
// import "@nomicfoundation/hardhat-toolbox";

// const config: HardhatUserConfig = {
//   solidity: "0.8.19",
// };

// export default config;

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("hardhat/config")
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      chainId: 1337,
    },
  },
};