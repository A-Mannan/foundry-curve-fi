// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ICurveStableSwapFactoryNG} from "../src/ICurveStableSwapFactoryNG.sol";
import {DeployStableSwapNGFactory} from "../script/DeployStableSwapNGFactory.s.sol";
import {DeployStableSwap3Pool} from "../script/DeployStableSwap3Pool.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock, ERC20} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockStETH} from "../src/MockStETH.sol";
import {ICurveStableSwapMetaNG} from "../src/ICurveStableSwapMetaNG.sol";
import {IStableSwap3Pool} from "../src/IStableSwap3Pool.sol";
import {ICurveLPToken} from "../src/ICurveLPToken.sol";
import {WETH} from "../src/WETH.sol";

contract StableSwapNGMetaPoolTest is Test {
    ICurveStableSwapFactoryNG public stableSwapFactory;
    ICurveStableSwapMetaNG public curveMetaPool;

    IStableSwap3Pool public curve3Pool;
    ICurveLPToken lpToken3Pool;

    ERC20 public usdc;
    ERC20 public usdt;
    ERC20 public dai;

    ERC20Mock public xusd;

    address public user = makeAddr("user");
    address public liquidityProvider = makeAddr("liquidityProvider");

    uint256 public constant STARTING_USER_BALANCE = 100 ether;
    uint256 public constant LP_DEPOSIT_AMOUNT = 10 ether;

    function setUp() public {
        DeployStableSwap3Pool curve3PoolDeployer = new DeployStableSwap3Pool();
        (
            address lpTokenAddr,
            address curve3PoolAddr,
            HelperConfig helperConfig
        ) = curve3PoolDeployer.run();
        lpToken3Pool = ICurveLPToken(lpTokenAddr);
        curve3Pool = IStableSwap3Pool(curve3PoolAddr);

        (, address usdcAddr, address usdtAddr, address daiAddr, ) = helperConfig
            .activeNetworkConfig();

        usdc = ERC20(usdcAddr);
        usdt = ERC20(usdtAddr);
        dai = ERC20(daiAddr);

        xusd = new ERC20Mock();

        DeployStableSwapNGFactory factoryDeployer = new DeployStableSwapNGFactory();
        (
            address stableSwapNGFactoryAddr,
            ,
            address metaPoolImpl,
            address mathImplAddr,

        ) = factoryDeployer.run();

        stableSwapFactory = ICurveStableSwapFactoryNG(stableSwapNGFactoryAddr);

        _setUpForMetaPoolDeployment(
            metaPoolImpl,
            mathImplAddr,
            curve3PoolAddr,
            lpTokenAddr
        );

        if (block.chainid == 31337) {
            ERC20Mock(usdcAddr).mint(liquidityProvider, STARTING_USER_BALANCE);
            ERC20Mock(usdtAddr).mint(liquidityProvider, STARTING_USER_BALANCE);
            ERC20Mock(daiAddr).mint(liquidityProvider, STARTING_USER_BALANCE);

            ERC20Mock(usdcAddr).mint(user, STARTING_USER_BALANCE);
            ERC20Mock(usdtAddr).mint(user, STARTING_USER_BALANCE);
            ERC20Mock(daiAddr).mint(user, STARTING_USER_BALANCE);
        }

        xusd.mint(liquidityProvider, STARTING_USER_BALANCE);
        xusd.mint(user, STARTING_USER_BALANCE);

        _provideLiquidityIn3Pool();

        address curveMetaPoolAddr = stableSwapFactory.deploy_metapool(
            curve3PoolAddr,
            "",
            "",
            address(xusd),
            200,
            4000000,
            20000000000,
            866,
            0,
            0,
            "",
            address(0)
        );

        curveMetaPool = ICurveStableSwapMetaNG(curveMetaPoolAddr);
    }

    function _setUpForMetaPoolDeployment(
        address metaPoolImpl,
        address mathImplAddr,
        address curve3PoolAddr,
        address lpTokenAddr
    ) internal {
        vm.startPrank(stableSwapFactory.admin());
        stableSwapFactory.set_metapool_implementations(0, metaPoolImpl);
        stableSwapFactory.set_math_implementation(mathImplAddr);

        stableSwapFactory.add_base_pool(
            curve3PoolAddr,
            lpTokenAddr,
            new uint8[](3),
            3
        );
        vm.stopPrank();
    }

    function _provideLiquidityIn3Pool() internal {
        vm.startPrank(liquidityProvider);

        uint256[3] memory amounts = [
            LP_DEPOSIT_AMOUNT,
            LP_DEPOSIT_AMOUNT,
            LP_DEPOSIT_AMOUNT
        ];

        usdc.approve(address(curve3Pool), LP_DEPOSIT_AMOUNT);
        usdt.approve(address(curve3Pool), LP_DEPOSIT_AMOUNT);
        dai.approve(address(curve3Pool), LP_DEPOSIT_AMOUNT);

        uint256 minMintAmount = 1 ether;

        curve3Pool.add_liquidity(amounts, minMintAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          ADD & REMOVE LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    function test_LiquidityProviderCanAddLiquidityIntoPool() public {
        // Arrange
        uint256 initial3PoolLPTokenBalance = lpToken3Pool.balanceOf(
            liquidityProvider
        );
        uint256 initialXusdBalance = xusd.balanceOf(liquidityProvider);
        uint256 initialMetaPoolTokenBalance = curveMetaPool.balanceOf(
            liquidityProvider
        );

        // Act
        vm.startPrank(liquidityProvider);
        xusd.approve(address(curveMetaPool), LP_DEPOSIT_AMOUNT);
        lpToken3Pool.approve(address(curveMetaPool), LP_DEPOSIT_AMOUNT);
        uint256[2] memory amounts = [LP_DEPOSIT_AMOUNT, LP_DEPOSIT_AMOUNT];
        uint256 minted = curveMetaPool.add_liquidity(
            amounts,
            1 ether,
            liquidityProvider
        );
        vm.stopPrank();

        // Assert
        uint256 ending3PoolLPTokenBalance = lpToken3Pool.balanceOf(
            liquidityProvider
        );
        uint256 endingXusdBalance = xusd.balanceOf(liquidityProvider);
        uint256 endingMetaPoolTokenBalance = curveMetaPool.balanceOf(
            liquidityProvider
        );

        assertEq(
            initial3PoolLPTokenBalance,
            ending3PoolLPTokenBalance + LP_DEPOSIT_AMOUNT
        );
        assertEq(initialXusdBalance, endingXusdBalance + LP_DEPOSIT_AMOUNT);
        assertEq(
            initialMetaPoolTokenBalance + minted,
            endingMetaPoolTokenBalance
        );
    }

    modifier WhenLPProvidedLiquidityInPool() {
        vm.startPrank(liquidityProvider);
        xusd.approve(address(curveMetaPool), LP_DEPOSIT_AMOUNT);
        lpToken3Pool.approve(address(curveMetaPool), LP_DEPOSIT_AMOUNT);
        uint256[2] memory amounts = [LP_DEPOSIT_AMOUNT, LP_DEPOSIT_AMOUNT];
        uint256 minted = curveMetaPool.add_liquidity(
            amounts,
            1 ether,
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
        uint256 initial3PoolLPTokenBalance = lpToken3Pool.balanceOf(
            liquidityProvider
        );
        uint256 initialXusdBalance = xusd.balanceOf(liquidityProvider);
        uint256 initialMetaPoolTokenBalance = curveMetaPool.balanceOf(
            liquidityProvider
        );

        uint256 lpAmountToDeposit = 1 ether;

        vm.prank(liquidityProvider);
        uint256[2] memory tokenAmounts = curveMetaPool.remove_liquidity(
            lpAmountToDeposit,
            [uint256(0.5 ether), uint256(0.5 ether)],
            liquidityProvider,
            false
        );

        // Assert
        uint256 ending3PoolLPTokenBalance = lpToken3Pool.balanceOf(
            liquidityProvider
        );
        uint256 endingXusdBalance = xusd.balanceOf(liquidityProvider);
        uint256 endingMetaPoolTokenBalance = curveMetaPool.balanceOf(
            liquidityProvider
        );

        assertEq(initialXusdBalance, endingXusdBalance - tokenAmounts[0]);
        assertEq(
            initial3PoolLPTokenBalance,
            ending3PoolLPTokenBalance - tokenAmounts[1]
        );
        assertEq(
            initialMetaPoolTokenBalance,
            endingMetaPoolTokenBalance + lpAmountToDeposit
        );
    }

    /*//////////////////////////////////////////////////////////////
                                EXCHANGE
    //////////////////////////////////////////////////////////////*/

    function test_UserCanExhangeXUSDFor3PoolLpTokenFromPool()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialUser3PoolLPTokenBalance = lpToken3Pool.balanceOf(user);
        uint256 initialUserXusdBalance = xusd.balanceOf(user);

        uint256 dx = 0.5 ether;
        uint256 min_dy = 0.49 ether;

        // Act
        vm.startPrank(user);
        xusd.approve(address(curveMetaPool), dx);
        uint256 dy = curveMetaPool.exchange(0, 1, dx, min_dy, user);
        vm.stopPrank();

        // Assert
        uint256 endingUser3PoolLPTokenBalance = lpToken3Pool.balanceOf(user);
        uint256 endingUserXusdBalance = xusd.balanceOf(user);

        assertEq(initialUserXusdBalance, endingUserXusdBalance + dx);
        assertEq(
            initialUser3PoolLPTokenBalance,
            endingUser3PoolLPTokenBalance - dy
        );
    }

    function test_UserCanExhangeXUSDForUnderlyingBaseTokensFromPool()
        public
        WhenLPProvidedLiquidityInPool
    {
        // Arrange
        uint256 initialUserXusdBalance = xusd.balanceOf(user);
        uint256 initialUserDaiBalance = dai.balanceOf(user);

        uint256 dx = 0.5 ether;
        uint256 min_dy = 0;

        // Act
        vm.startPrank(user);
        xusd.approve(address(curveMetaPool), dx);
        uint256 dy = curveMetaPool.exchange_underlying(0, 3, dx, min_dy, user);
        vm.stopPrank();

        // Assert
        uint256 endingUserXusdBalance = xusd.balanceOf(user);
        uint256 endingUserDaiBalance = dai.balanceOf(user);

        assertEq(initialUserXusdBalance, endingUserXusdBalance + dx);
        assertEq(
            initialUserDaiBalance,
            endingUserDaiBalance - dy
        );
    }
}
