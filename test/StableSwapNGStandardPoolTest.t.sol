// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ICurveStableSwapFactoryNG} from "../src/ICurveStableSwapFactoryNG.sol";
import {DeployStableSwapNGFactory} from "../script/DeployStableSwapNGFactory.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockStETH} from "../src/MockStETH.sol";
import {ICurveStableSwapNG} from "../src/ICurveStableSwapNG.sol";

contract StableSwapNGStandardPoolTest is Test {
    ICurveStableSwapFactoryNG public stableSwapFactory;
    ICurveStableSwapNG public curvePlainPool;

    ERC20Mock public tokenA;
    ERC20Mock public tokenB;

    MockStETH public mockStEth;

    address public user = makeAddr("user");
    address public liquidityProvider = makeAddr("liquidityProvider");

    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    function setUp() public {
        DeployStableSwapNGFactory deployer = new DeployStableSwapNGFactory();
        (
            address stableSwapNGFactoryAddr,
            address plainPoolImplAddr,
            ,
            ,

        ) = deployer.run();

        stableSwapFactory = ICurveStableSwapFactoryNG(stableSwapNGFactoryAddr);

        vm.prank(stableSwapFactory.admin());
        stableSwapFactory.set_pool_implementations(0, plainPoolImplAddr);

        tokenA = new ERC20Mock();
        tokenB = new ERC20Mock();

        address[] memory coins = new address[](2);
        coins[0] = address(tokenA);
        coins[1] = address(tokenB);

        address curvePoolAddr = stableSwapFactory.deploy_plain_pool(
            "",
            "",
            coins,
            200,
            4000000,
            20000000000,
            866,
            0,
            new uint8[](2),
            new bytes4[](2),
            new address[](2)
        );

        curvePlainPool = ICurveStableSwapNG(curvePoolAddr);

        if (block.chainid == 31337) {
            // hoax(liquidityProvider, 2 * STARTING_USER_BALANCE);
            tokenA.mint(liquidityProvider, STARTING_USER_BALANCE);
            tokenB.mint(liquidityProvider, STARTING_USER_BALANCE);
            // mockStEth.submit{value: STARTING_USER_BALANCE}();

            // hoax(user, 2 * STARTING_USER_BALANCE);
            tokenA.mint(user, STARTING_USER_BALANCE);
            tokenB.mint(user, STARTING_USER_BALANCE);
            // mockStEth.submit{value: STARTING_USER_BALANCE}();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ADD & REMOVE LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    function test_LiquidityProviderCanAddLiquidityIntoPool() public {
        // Arrange
        uint256 initialTokenABalance = tokenA.balanceOf(liquidityProvider);
        uint256 initialTokenBBalance = tokenB.balanceOf(liquidityProvider);
        uint256 initialLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        uint256 tokenADepositAmount = 1 ether;
        uint256 tokenBDepositAmount = 1 ether;
        uint256 minLPMintAmount = 1 ether;

        // Act
        vm.startPrank(liquidityProvider);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = tokenADepositAmount;
        amounts[1] = tokenBDepositAmount;

        tokenA.approve(address(curvePlainPool), tokenBDepositAmount);
        tokenB.approve(address(curvePlainPool), tokenBDepositAmount);

        uint256 minted = curvePlainPool.add_liquidity(
            amounts,
            minLPMintAmount,
            liquidityProvider
        );
        vm.stopPrank();

        // Assert
        uint256 endingTokenABalance = tokenA.balanceOf(liquidityProvider);
        uint256 endingTokenBBalance = tokenB.balanceOf(liquidityProvider);
        uint256 endingLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        assertEq(
            initialTokenABalance,
            endingTokenABalance + tokenADepositAmount
        );
        assertEq(
            initialTokenBBalance,
            endingTokenBBalance + tokenBDepositAmount
        );
        assertEq(initialLpTokenBalance, endingLpTokenBalance - minted);
    }

    modifier WhenLPProvidedLiquidityInPool() {
        uint256 tokenADepositAmount = 1 ether;
        uint256 tokenBDepositAmount = 1 ether;
        uint256 minLPMintAmount = 1 ether;

        // Act
        vm.startPrank(liquidityProvider);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = tokenADepositAmount;
        amounts[1] = tokenBDepositAmount;

        tokenA.approve(address(curvePlainPool), tokenBDepositAmount);
        tokenB.approve(address(curvePlainPool), tokenBDepositAmount);

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
        /// Arrange
        uint256 initialTokenABalance = tokenA.balanceOf(liquidityProvider);
        uint256 initialTokenBBalance = tokenB.balanceOf(liquidityProvider);
        uint256 initialLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        uint256 tokenAMinWithdrawAmount = 0.5 ether;
        uint256 tokenBMinWithdrawAmount = 0.5 ether;

        uint256 lpAmountToDeposit = 1 ether;
        uint256[] memory minAmounts = new uint256[](2);
        minAmounts[0] = tokenAMinWithdrawAmount;
        minAmounts[1] = tokenBMinWithdrawAmount;

        // Act
        vm.prank(liquidityProvider);
        uint256[] memory tokenAmounts = curvePlainPool.remove_liquidity(
            lpAmountToDeposit,
            minAmounts,
            liquidityProvider,
            false
        );

        // Assert
        uint256 endingTokenABalance = tokenA.balanceOf(liquidityProvider);
        uint256 endingTokenBBalance = tokenB.balanceOf(liquidityProvider);
        uint256 endingLpTokenBalance = curvePlainPool.balanceOf(
            liquidityProvider
        );

        assertEq(initialTokenABalance, endingTokenABalance - tokenAmounts[0]);
        assertEq(initialTokenBBalance, endingTokenBBalance - tokenAmounts[1]);
        assertEq(
            initialLpTokenBalance,
            endingLpTokenBalance + lpAmountToDeposit
        );
    }

    /*//////////////////////////////////////////////////////////////
                                EXCHANGE
    //////////////////////////////////////////////////////////////*/

    function test_UserCanExhangeTokenAForTokenBFromPool()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialUserTokenABalance = tokenA.balanceOf(user);
        uint256 initialUserTokenBBalance = tokenB.balanceOf(user);

        uint256 dx = 0.5 ether;
        uint256 min_dy = 0.49 ether;

        // Act
        vm.startPrank(user);
        tokenA.approve(address(curvePlainPool), dx);
        uint256 dy = curvePlainPool.exchange(0, 1, dx, min_dy, user);
        vm.stopPrank();

        // Assert
        uint256 endingUserTokenABalance = tokenA.balanceOf(user);
        uint256 endingUserTokenBBalance = tokenB.balanceOf(user);

        assertEq(initialUserTokenABalance, endingUserTokenABalance + dx);
        assertEq(initialUserTokenBBalance, endingUserTokenBBalance - dy);
    }

    function test_UserCanExhangeTokenBForTokenAFromPool()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialUserTokenABalance = tokenA.balanceOf(user);
        uint256 initialUserTokenBBalance = tokenB.balanceOf(user);

        uint256 dx = 0.5 ether;
        uint256 min_dy = 0.49 ether;

        // Act
        vm.startPrank(user);
        tokenB.approve(address(curvePlainPool), dx);
        uint256 dy = curvePlainPool.exchange(1, 0, dx, min_dy, user);
        vm.stopPrank();

        // Assert
        uint256 endingUserTokenABalance = tokenA.balanceOf(user);
        uint256 endingUserTokenBBalance = tokenB.balanceOf(user);

        assertEq(initialUserTokenABalance, endingUserTokenABalance - dy);
        assertEq(initialUserTokenBBalance, endingUserTokenBBalance + dx);
    }
}
