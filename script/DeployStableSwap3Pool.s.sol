// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {VyperDeployer} from "../lib/utils/VyperDeployer.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ICurveLPToken} from "../src/ICurveLPToken.sol";

contract DeployStableSwap3Pool is VyperDeployer, Script {
    address[3] public tokenAddresses;

    function run()
        public
        returns (
            address LPTokenAddr,
            address curve3PoolAddr,
            HelperConfig helperConfig
        )
    {
        helperConfig = new HelperConfig();

        (
            ,
            address usdc,
            address usdt,
            address dai,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        tokenAddresses = [usdc, usdt, dai];

        vm.startBroadcast(deployerKey);
        LPTokenAddr = deployContract(
            "CurveTokenV3",
            abi.encode("Curve.fi ETH/stETH", "steCRV")
        );
        curve3PoolAddr = deployContract(
            "StableSwap3Pool",
            abi.encode(
                msg.sender,
                tokenAddresses,
                LPTokenAddr,
                200,
                1000000,
                5000000000
            )
        );
        ICurveLPToken(LPTokenAddr).set_minter(curve3PoolAddr);

        vm.stopBroadcast();
    }
}
