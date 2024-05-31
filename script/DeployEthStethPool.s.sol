// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {VyperDeployer} from "../lib/utils/VyperDeployer.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ICurveLPToken} from "../src/ICurveLPToken.sol";

contract DeployEthStethPool is VyperDeployer, Script {
    address[2] public tokenAddresses;

    function run()
        public
        returns (
            address LPTokenAddr,
            address ethStethPoolAddr,
            HelperConfig helperConfig
        )
    {
        helperConfig = new HelperConfig(); // This comes with our mocks!

        (address steth, , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();

        address ethPlaceholder = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        tokenAddresses = [ethPlaceholder, steth];

        vm.startBroadcast(deployerKey);
        // VyperDeployer vyperDeployer = new VyperDeployer();
        LPTokenAddr = deployContract(
            "CurveTokenV3",
            abi.encode("Curve.fi ETH/stETH", "steCRV")
        );
        ethStethPoolAddr = deployContract(
            "StableSwapSTETH",
            abi.encode(
                msg.sender,
                tokenAddresses,
                LPTokenAddr,
                200,
                1000000,
                5000000000
            )
        );
        ICurveLPToken(LPTokenAddr).set_minter(ethStethPoolAddr);

        vm.stopBroadcast();
    }
}
