// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ICurveStableSwapFactoryNG} from "../src/ICurveStableSwapFactoryNG.sol";
import {DeployStableSwapNGFactory} from "../script/DeployStableSwapNGFactory.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockStETH} from "../src/MockStETH.sol";
import {ICurveStableSwapNG} from "../src/ICurveStableSwapNG.sol";
import {WETH} from "../src/WETH.sol";

contract StableSwapNGRebasingPoolTest is Test {
    ICurveStableSwapFactoryNG public stableSwapFactory;
    ICurveStableSwapNG public curvePlainPool;

    WETH public weth;
    MockStETH public mockStEth;

    address public user = makeAddr("user");
    address public liquidityProvider = makeAddr("liquidityProvider");

    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    uint256 public constant LP_DEPOSIT_AMOUNT = 1 ether;

    function setUp() public {
        DeployStableSwapNGFactory deployer = new DeployStableSwapNGFactory();
        (
            address stableSwapNGFactoryAddr,
            address plainPoolImplAddr,
            ,
            ,
            HelperConfig helperConfig
        ) = deployer.run();

        (address stEthAddr, , , ,) = helperConfig.activeNetworkConfig();
        mockStEth = MockStETH(stEthAddr);
        weth = new WETH();

        stableSwapFactory = ICurveStableSwapFactoryNG(stableSwapNGFactoryAddr);

        vm.prank(stableSwapFactory.admin());
        stableSwapFactory.set_pool_implementations(0, plainPoolImplAddr);

        address[] memory coins = new address[](2);
        coins[0] = address(weth);
        coins[1] = address(mockStEth);

        uint8[] memory assetTypes = new uint8[](2);
        assetTypes[0] = 0;
        assetTypes[1] = 2;

        address curvePoolAddr = stableSwapFactory.deploy_plain_pool(
            "",
            "",
            coins,
            200,
            4000000,
            20000000000,
            866,
            0,
            assetTypes,
            new bytes4[](2),
            new address[](2)
        );

        curvePlainPool = ICurveStableSwapNG(curvePoolAddr);

        if (block.chainid == 31337) {
            vm.deal(liquidityProvider, 2 * STARTING_USER_BALANCE);
            vm.startPrank(liquidityProvider);
            weth.deposit{value: STARTING_USER_BALANCE}();
            mockStEth.submit{value: STARTING_USER_BALANCE}();
            vm.stopPrank();

            vm.deal(user, 2 * STARTING_USER_BALANCE);
            vm.startPrank(user);
            weth.deposit{value: STARTING_USER_BALANCE}();
            mockStEth.submit{value: STARTING_USER_BALANCE}();
            vm.stopPrank();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ADD & REMOVE LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    function test_LiquidityProviderCanAddLiquidityIntoPool() public {
        // Arrange
        uint256 initialWethBalance = weth.balanceOf(liquidityProvider);
        uint256 initialStEthBalance = mockStEth.balanceOf(liquidityProvider);
        uint256 initialLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        uint256 wethDepositAmount = LP_DEPOSIT_AMOUNT;
        uint256 mockStEthDepositAmount = LP_DEPOSIT_AMOUNT;
        uint256 minLPMintAmount = 1 ether;

        // Act
        vm.startPrank(liquidityProvider);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = wethDepositAmount;
        amounts[1] = mockStEthDepositAmount;

        weth.approve(address(curvePlainPool), wethDepositAmount);
        mockStEth.approve(address(curvePlainPool), mockStEthDepositAmount);

        uint256 minted = curvePlainPool.add_liquidity(
            amounts,
            minLPMintAmount,
            liquidityProvider
        );
        vm.stopPrank();

        // Assert
        uint256 endingWethBalance = weth.balanceOf(liquidityProvider);
        uint256 endingStEthBalance = mockStEth.balanceOf(liquidityProvider);
        uint256 endingLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        assertEq(initialWethBalance, endingWethBalance + wethDepositAmount);
        assertEq(
            initialStEthBalance,
            endingStEthBalance + mockStEthDepositAmount
        );
        assertEq(initialLpTokenBalance, endingLpTokenBalance - minted);
    }

    modifier WhenLPProvidedLiquidityInPool() {
        uint256 wethDepositAmount = LP_DEPOSIT_AMOUNT;
        uint256 mockStEthDepositAmount = LP_DEPOSIT_AMOUNT;
        uint256 minLPMintAmount = 1 ether;

        vm.startPrank(liquidityProvider);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = wethDepositAmount;
        amounts[1] = mockStEthDepositAmount;

        weth.approve(address(curvePlainPool), wethDepositAmount);
        mockStEth.approve(address(curvePlainPool), mockStEthDepositAmount);

        uint256 minted = curvePlainPool.add_liquidity(
            amounts,
            minLPMintAmount,
            liquidityProvider
        );
        vm.stopPrank();
        _;
    }

    function test_LiquidityProviderCanRemoveLiquidityFromPool()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialWethBalance = weth.balanceOf(liquidityProvider);
        uint256 initialStEthBalance = mockStEth.balanceOf(liquidityProvider);
        uint256 initialLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        uint256 wethMinWithdrawAmount = 0.5 ether;
        uint256 stEthMinWithdrawAmount = 0.5 ether;

        uint256 lpAmountToDeposit = 1 ether;
        uint256[] memory minAmounts = new uint256[](2);
        minAmounts[0] = wethMinWithdrawAmount;
        minAmounts[1] = stEthMinWithdrawAmount;

        // Act
        vm.prank(liquidityProvider);
        uint256[] memory tokenAmounts = curvePlainPool.remove_liquidity(
            lpAmountToDeposit,
            minAmounts,
            liquidityProvider,
            false
        );

        // Assert
        uint256 endingWethBalance = weth.balanceOf(liquidityProvider);
        uint256 endingStEthBalance = mockStEth.balanceOf(liquidityProvider);
        uint256 endingLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        assertEq(initialWethBalance, endingWethBalance - tokenAmounts[0]);
        assertEq(initialStEthBalance, endingStEthBalance - tokenAmounts[1]);
        assertEq(
            initialLpTokenBalance,
            endingLpTokenBalance + lpAmountToDeposit
        );
    }

    // /*//////////////////////////////////////////////////////////////
    //                             EXCHANGE
    // //////////////////////////////////////////////////////////////*/

    function test_UserCanExhangeWethForStEthFromPool()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialUserWethBalance = weth.balanceOf(user);
        uint256 initialUserStEthBalance = mockStEth.balanceOf(user);

        uint256 dx = 0.5 ether;
        uint256 min_dy = 0.49 ether;

        // Act
        vm.startPrank(user);
        weth.approve(address(curvePlainPool), dx);
        uint256 dy = curvePlainPool.exchange(0, 1, dx, min_dy, user);
        vm.stopPrank();

        // Assert
        uint256 endingUserWethBalance = weth.balanceOf(user);
        uint256 endingUserStEthBalance = mockStEth.balanceOf(user);

        assertEq(initialUserWethBalance, endingUserWethBalance + dx);
        assertEq(initialUserStEthBalance, endingUserStEthBalance - dy);
    }

    function test_UserCanExhangemockStEthForwethFromPool()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialUserWethBalance = weth.balanceOf(user);
        uint256 initialUserStEthBalance = mockStEth.balanceOf(user);

        uint256 dx = 0.5 ether;
        uint256 min_dy = 0.49 ether;

        // Act
        vm.startPrank(user);
        mockStEth.approve(address(curvePlainPool), dx);
        uint256 dy = curvePlainPool.exchange(1, 0, dx, min_dy, user);
        vm.stopPrank();

        // Assert
        uint256 endingUserWethBalance = weth.balanceOf(user);
        uint256 endingUserStEthBalance = mockStEth.balanceOf(user);

        assertEq(initialUserWethBalance, endingUserWethBalance - dy);
        assertEq(initialUserStEthBalance, endingUserStEthBalance + dx);
    }

    /*//////////////////////////////////////////////////////////////
                        STETH REBASES REWARDS
    //////////////////////////////////////////////////////////////*/

    function test_PoolStEthBalanceIncreasesWhenStEthRebasesAccumulatedRewards()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialPoolStEthBalance = curvePlainPool.balances(1);

        // Act
        hoax(mockStEth.owner(), 1 ether);
        mockStEth.accumulateRewards{value: 1 ether}();

        // Assert
        uint256 endingPoolStEthBalance = curvePlainPool.balances(1);

        emit log_named_uint("Initial StEth balance", initialPoolStEthBalance);
        emit log_named_uint("Ending StEth balance", endingPoolStEthBalance);
        assertGt(endingPoolStEthBalance, initialPoolStEthBalance);
    }

    modifier WhenStEthRebasesAccumulatedRewards() {
        hoax(mockStEth.owner(), 1 ether);
        mockStEth.accumulateRewards{value: 1 ether}();
        _;
    }

    function test_UserGetsMoreStEthWhenRemovingLiquidityFromPool()
        public
        WhenLPProvidedLiquidityInPool
        WhenStEthRebasesAccumulatedRewards
    {
        // Arrange
        uint256 initialWethBalance = weth.balanceOf(liquidityProvider);
        uint256 initialStEthBalance = mockStEth.balanceOf(liquidityProvider);
        uint256 initialLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        uint256 wethMinWithdrawAmount = LP_DEPOSIT_AMOUNT / 2;
        uint256 stEthMinWithdrawAmount = LP_DEPOSIT_AMOUNT / 2;

        uint256 lpAmountToDeposit = 2 ether;
        uint256[] memory minAmounts = new uint256[](2);
        minAmounts[0] = wethMinWithdrawAmount;
        minAmounts[1] = stEthMinWithdrawAmount;

        // Act
        vm.prank(liquidityProvider);
        uint256[] memory tokenAmounts = curvePlainPool.remove_liquidity(
            lpAmountToDeposit,
            minAmounts,
            liquidityProvider,
            false
        );

        // Assert
        uint256 endingWethBalance = weth.balanceOf(liquidityProvider);
        uint256 endingStEthBalance = mockStEth.balanceOf(liquidityProvider);
        uint256 endingLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        assertEq(initialWethBalance, endingWethBalance - tokenAmounts[0]);
        assertApproxEqAbs(initialStEthBalance, endingStEthBalance - tokenAmounts[1], 5);
        assertEq(
            initialLpTokenBalance,
            endingLpTokenBalance + lpAmountToDeposit
        );

        assertGt(tokenAmounts[1], LP_DEPOSIT_AMOUNT/2);
    }
}
