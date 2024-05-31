// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockStETH} from "../src/MockStETH.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;


    struct NetworkConfig {
        address steth;
        address usdc;
        address usdt;
        address dai;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 5) {
            activeNetworkConfig = getGoerliEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        // sepoliaNetworkConfig = NetworkConfig({
        //     steth: address(0),
        //     deployerKey: vm.envUint("PRIVATE_KEY")
        // });
    }

    function getGoerliEthConfig()
        public
        view
        returns (NetworkConfig memory goerliNetworkConfig)
    {}

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        // Check to see if we set an active network config
        if (activeNetworkConfig.steth != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockStETH stethMock = new MockStETH();
        ERC20Mock dai = new ERC20Mock();
        ERC20Mock usdt = new ERC20Mock();
        ERC20Mock usdc = new ERC20Mock();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            steth: address(stethMock),
            usdc: address(usdc),
            usdt: address(usdt),
            dai: address(dai),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
