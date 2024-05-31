// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {VyperDeployer} from "../lib/utils/VyperDeployer.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployStableSwapNGFactory is VyperDeployer, Script {
    function run()
        public
        returns (
            address stableSwapNGFactoryAddr,
            address plainPoolImplAddr,
            address metaPoolImplAddr,
            address mathImplAddr,
            HelperConfig helperConfig
        )
    {
        helperConfig = new HelperConfig();

        (, , , , uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);

        stableSwapNGFactoryAddr = deployContract("CurveStableSwapFactoryNG");
        plainPoolImplAddr = deployBlueprint("CurveStableSwapNG");
        metaPoolImplAddr = deployBlueprint("CurveStableSwapMetaNG");
        mathImplAddr = deployContract("CurveStableSwapNGMath");

        vm.stopBroadcast();
    }

    function deployCurveStableSwapFactoryNG() internal returns (address) {
        return
            deployContract(
                "CurveStableSwapFactoryNG",
                abi.encode(msg.sender, msg.sender)
            );
    }
}
