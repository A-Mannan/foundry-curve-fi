// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "lib/utils/VyperDeployer.sol";

import "../src/ISimpleStore.sol";
import {ICurveLPToken} from "../src/ICurveLPToken.sol";

contract SimpleStoreTest is Test {
    ///@notice create a new instance of VyperDeployer
    VyperDeployer vyperDeployer = new VyperDeployer();

    ISimpleStore simpleStore;
    ISimpleStore simpleStoreBlueprint;
    ISimpleStoreFactory simpleStoreFactory;

    function setUp() public {
        ///@notice deploy a new instance of ISimplestore by passing in the address of the deployed Vyper contract
        simpleStore = ISimpleStore(
            vyperDeployer.deployContract("SimpleStore", abi.encode(1234))
        );

        simpleStoreBlueprint = ISimpleStore(
            vyperDeployer.deployBlueprint("ExampleBlueprint")
        );

        simpleStoreFactory = ISimpleStoreFactory(
            vyperDeployer.deployContract("SimpleStoreFactory")
        );
        address LPTokenAddr = vyperDeployer.deployContract(
            "CurveTokenV3",
            abi.encode("Curve.fi ETH/stETH", "steCRV")
        );
        emit log_named_address("lp token", LPTokenAddr);

    }


    function testGet() public {
        uint256 val = simpleStore.get();

        require(val == 1234);
    }

    function testStore(uint256 _val) public {
        simpleStore.store(_val);
        uint256 val = simpleStore.get();

        require(_val == val);
    }

    function testFactory() public {
        address deployedAddress = simpleStoreFactory.deploy(
            address(simpleStoreBlueprint),
            1354
        );

        ISimpleStore deployedSimpleStore = ISimpleStore(deployedAddress);

        uint256 val = deployedSimpleStore.get();

        require(val == 1354);

        deployedSimpleStore.store(1234);

        val = deployedSimpleStore.get();

        require(val == 1234);
    }
}
