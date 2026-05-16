pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/core/PredictionMarket.sol";
import "../../src/core/FeeVault.sol";
import "../../src/tokens/OutcomeToken.sol";
import "../../src/mock/MockUSDC.sol";
import "../../src/mock/MockAggregator.sol";
import "../../src/oracles/ChainlinkPriceFeed.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PredictionMarketTest is Test {
    PredictionMarket public market;
    OutcomeToken public ot;
    MockUSDC public baseToken;
    MockAggregator public aggregator;
    ChainlinkPriceFeed public priceFeed;
    FeeVault public feeVault;
    ERC1967Proxy public feeVaultProxy;

    address public admin = address(0x1);
    address public resolver = address(0x2);
    address public trader = address(0x3);
    address public lp = address(0x4);
    address public constant FEE_VAULT_ADMIN = address(0x10);

    uint256 public yesId;
    uint256 public noId;
    uint256 public resolutionTime;
    uint256 public disputeWindow = 2 days;

    function setUp() public {
        vm.warp(1_000_000);

        baseToken = new MockUSDC();
        aggregator = new MockAggregator(2000e8);
        priceFeed = new ChainlinkPriceFeed(address(aggregator), 3600);
        feeVault = new FeeVault();
        feeVaultProxy = new ERC1967Proxy(address(feeVault), abi.encodeWithSelector(FeeVault.initialize.selector, address(baseToken), FEE_VAULT_ADMIN));

        ot = new OutcomeToken("Outcome", "OC", "https://api.predmarket.io/metadata/");
        yesId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(1))));
        noId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(2))));

        resolutionTime = block.timestamp + 7 days;

        market = new PredictionMarket(
            "Will ETH reach $5000 by June 2026?",
            resolutionTime,
            disputeWindow,
            address(ot),
            yesId,
            noId,
            address(baseToken),
            30,
            address(feeVaultProxy),
            address(priceFeed),
            resolver
        );

        ot.grantRole(ot.MINTER_ROLE(), address(market));
        ot.grantRole(ot.BURNER_ROLE(), address(market));

        vm.startPrank(admin);
        baseToken.mint(trader, 1_000_000e6);
        baseToken.mint(lp, 1_000_000e6);
        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(market.question(), "Will ETH reach $5000 by June 2026?");
        assertEq(market.resolutionTime(), resolutionTime);
        assertEq(market.disputeWindow(), disputeWindow);
        assertEq(market.feeBps(), 30);
        assertEq(market.resolved(), false);
        assertEq(address(market.outcomeToken()), address(ot));
        assertEq(address(market.baseToken()), address(baseToken));
        assertEq(market.feeVault(), address(feeVaultProxy));
    }

    function test_SplitBase() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.splitBase(100e6);
        vm.stopPrank();

        assertEq(ot.balanceOf(trader, yesId), 100e6);
        assertEq(ot.balanceOf(trader, noId), 100e6);
        assertEq(baseToken.balanceOf(address(market)), 100e6);
    }

    function test_SplitBaseRevertZeroAmount() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.ZeroAmount.selector));
        market.splitBase(0);
        vm.stopPrank();
    }

    function test_MergeOutcomes() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.splitBase(100e6);
        ot.setApprovalForAll(address(market), true);
        market.mergeOutcomes(50e6);
        vm.stopPrank();

        assertEq(ot.balanceOf(trader, yesId), 50e6);
        assertEq(ot.balanceOf(trader, noId), 50e6);
        assertEq(baseToken.balanceOf(trader), 1_000_000e6 - 100e6 + 50e6);
    }

    function test_SplitThenMergeFully() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.splitBase(100e6);
        ot.setApprovalForAll(address(market), true);
        market.mergeOutcomes(100e6);
        vm.stopPrank();

        assertEq(ot.balanceOf(trader, yesId), 0);
        assertEq(ot.balanceOf(trader, noId), 0);
        assertEq(baseToken.balanceOf(trader), 1_000_000e6);
    }

    function test_BuyOutcomeYes() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        uint256 out = market.buyOutcome(1, 100e6, 0);
        vm.stopPrank();

        assertTrue(out > 100e6, "Should get more than input YES tokens");
        assertEq(ot.balanceOf(trader, yesId), out);
        assertEq(ot.balanceOf(trader, noId), 0);
        assertTrue(market.reserveNo() > 0, "NO reserve should increase");
    }

    function test_BuyOutcomeNo() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.buyOutcome(2, 100e6, 0);
        vm.stopPrank();

        assertEq(ot.balanceOf(trader, yesId), 0);
        assertTrue(ot.balanceOf(trader, noId) > 100e6);
    }

    function test_BuyOutcomeUpdatesReserves() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        (uint256 ryBefore, uint256 rnBefore) = market.getReserves();

        market.buyOutcome(1, 100e6, 0);
        (uint256 ryAfter, uint256 rnAfter) = market.getReserves();
        vm.stopPrank();

        assertTrue(ryAfter < ryBefore, "YES reserve should decrease");
        assertTrue(rnAfter > rnBefore, "NO reserve should increase");
    }

    function test_BuyOutcomeRevertsAfterResolution() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        vm.stopPrank();

        vm.prank(resolver);
        market.resolveMarket(1);

        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.AlreadyResolved.selector));
        market.buyOutcome(1, 100e6, 0);
        vm.stopPrank();
    }

    function test_BuyOutcomeRevertsZeroAmount() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.ZeroAmount.selector));
        market.buyOutcome(1, 0, 0);
        vm.stopPrank();
    }

    function test_BuyOutcomeRevertsInvalidOutcome() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.InvalidOutcome.selector));
        market.buyOutcome(3, 100e6, 0);
        vm.stopPrank();
    }

    function test_SellOutcome() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.buyOutcome(1, 100e6, 0);
        uint256 yesBalance = ot.balanceOf(trader, yesId);

        ot.setApprovalForAll(address(market), true);
        market.sellOutcome(1, yesBalance, 0);
        vm.stopPrank();

        assertTrue(ot.balanceOf(trader, yesId) < yesBalance);
    }

    function test_AddLiquidity() public {
        vm.startPrank(lp);
        baseToken.approve(address(market), 1000e6);
        uint256 shares = market.addLiquidity(1000e6);
        vm.stopPrank();

        assertTrue(shares > 0);
        assertEq(market.lpShares(lp), shares);
        assertTrue(market.totalLpShares() >= shares);
        (uint256 ry, uint256 rn) = market.getReserves();
        assertEq(ry, 1000e6);
        assertEq(rn, 1000e6);
    }

    function test_AddLiquidityTwice() public {
        vm.startPrank(lp);
        baseToken.approve(address(market), 1000e6);
        market.addLiquidity(1000e6);
        market.addLiquidity(500e6);
        vm.stopPrank();

        (uint256 ry, uint256 rn) = market.getReserves();
        assertEq(ry, 1500e6);
        assertEq(rn, 1500e6);
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(lp);
        baseToken.approve(address(market), 1000e6);
        uint256 shares = market.addLiquidity(1000e6);
        uint256 lpBalanceYesBefore = ot.balanceOf(lp, yesId);
        uint256 lpBalanceNoBefore = ot.balanceOf(lp, noId);

        ot.setApprovalForAll(address(market), true);
        (uint256 amountYes, uint256 amountNo) = market.removeLiquidity(shares);
        vm.stopPrank();

        assertTrue(amountYes > 0);
        assertTrue(amountNo > 0);
        assertEq(market.lpShares(lp), 0);
        assertTrue(ot.balanceOf(lp, yesId) > lpBalanceYesBefore);
        assertTrue(ot.balanceOf(lp, noId) > lpBalanceNoBefore);
    }

    function test_ResolveMarket() public {
        vm.prank(resolver);
        market.resolveMarket(1);

        assertTrue(market.resolved());
        assertEq(market.winner(), 1);
    }

    function test_ResolveMarketRevertsFromNonResolver() public {
        vm.expectRevert();
        vm.prank(trader);
        market.resolveMarket(1);
    }

    function test_ResolveMarketRevertsTooEarly() public {
        vm.warp(resolutionTime - 1);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.NotResolvedYet.selector));
        vm.prank(resolver);
        market.resolveMarket(1);
    }

    function test_ResolveMarketRevertsAlreadyResolved() public {
        vm.prank(resolver);
        market.resolveMarket(1);

        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.AlreadyResolved.selector));
        vm.prank(resolver);
        market.resolveMarket(1);
    }

    function test_ResolveMarketRevertsInvalidOutcome() public {
        vm.warp(resolutionTime);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.InvalidOutcome.selector));
        vm.prank(resolver);
        market.resolveMarket(3);
    }

    function test_RedeemWinningOutcome() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.buyOutcome(1, 100e6, 0);
        vm.stopPrank();

        vm.warp(resolutionTime);
        vm.prank(resolver);
        market.resolveMarket(1);

        uint256 balanceBefore = baseToken.balanceOf(trader);
        ot.setApprovalForAll(address(market), true);
        vm.startPrank(trader);
        market.redeem(1);
        vm.stopPrank();

        assertTrue(baseToken.balanceOf(trader) > balanceBefore);
    }

    function test_RedeemRevertsOnLosingOutcome() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.buyOutcome(1, 100e6, 0);
        vm.stopPrank();

        vm.warp(resolutionTime);
        vm.prank(resolver);
        market.resolveMarket(2);

        vm.startPrank(trader);
        ot.setApprovalForAll(address(market), true);
        vm.expectRevert("Not winning outcome");
        market.redeem(1);
        vm.stopPrank();
    }

    function test_RedeemRevertsWhenNotResolved() public {
        vm.startPrank(trader);
        ot.setApprovalForAll(address(market), true);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.NotResolved.selector));
        market.redeem(1);
        vm.stopPrank();
    }

    function test_DisputeAndReresolve() public {
        vm.prank(resolver);
        market.resolveMarket(1);

        vm.prank(resolver);
        market.raiseDispute();

        assertFalse(market.resolved());
        assertEq(market.winner(), 0);
    }

    function test_RaiseDisputeAfterWindow() public {
        vm.warp(resolutionTime);
        vm.prank(resolver);
        market.resolveMarket(1);

        vm.warp(block.timestamp + disputeWindow);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.DisputeWindowClosed.selector));
        vm.prank(resolver);
        market.raiseDispute();
    }

    function test_GetPrice() public {
        uint256 priceYes = market.getPrice(1);
        assertEq(priceYes, 0);

        vm.startPrank(lp);
        baseToken.approve(address(market), 1000e6);
        market.addLiquidity(1000e6);
        vm.stopPrank();

        priceYes = market.getPrice(1);
        assertEq(priceYes, 0.5e18);
        assertEq(market.getPrice(2), 0.5e18);
    }

    function test_GetPriceAfterBuy() public {
        vm.startPrank(lp);
        baseToken.approve(address(market), 1000e6);
        market.addLiquidity(1000e6);
        vm.stopPrank();

        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.buyOutcome(1, 100e6, 0);
        vm.stopPrank();

        assertTrue(market.getPrice(1) > 0.5e18);
        assertTrue(market.getPrice(2) < 0.5e18);
    }

    function test_GetReserves() public {
        (uint256 ry, uint256 rn) = market.getReserves();
        assertEq(ry, 0);
        assertEq(rn, 0);
    }

    function test_FeesCollected() public {
        vm.startPrank(lp);
        baseToken.approve(address(market), 1000e6);
        market.addLiquidity(1000e6);
        vm.stopPrank();

        vm.startPrank(trader);
        baseToken.approve(address(market), 10000e6);
        market.buyOutcome(1, 10000e6, 0);
        vm.stopPrank();

        assertTrue(baseToken.balanceOf(address(feeVaultProxy)) > 0);
    }

    function test_SwapTokenForToken() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.splitBase(100e6);
        ot.setApprovalForAll(address(market), true);
        uint256 out = market.swap(noId, yesId, 50e6, 0);
        vm.stopPrank();

        assertTrue(out > 0);
    }

    function test_SwapRevertsPastResolution() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.splitBase(100e6);
        vm.stopPrank();

        vm.warp(resolutionTime);
        vm.startPrank(trader);
        ot.setApprovalForAll(address(market), true);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.TradingEnded.selector));
        market.swap(noId, yesId, 50e6, 0);
        vm.stopPrank();
    }

    function test_OnlyManagerCanRaiseDispute() public {
        vm.warp(resolutionTime);
        vm.prank(resolver);
        market.resolveMarket(1);

        vm.expectRevert();
        vm.prank(trader);
        market.raiseDispute();
    }

    function testSlippageProtection() public {
        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.SlippageExceeded.selector));
        market.buyOutcome(1, 100e6, 1e30);
        vm.stopPrank();
    }

    function test_MultipleTraders() public {
        address trader2 = address(0x5);
        baseToken.mint(trader2, 1_000_000e6);

        vm.startPrank(lp);
        baseToken.approve(address(market), 10000e6);
        market.addLiquidity(10000e6);
        vm.stopPrank();

        vm.startPrank(trader);
        baseToken.approve(address(market), 100e6);
        market.buyOutcome(1, 100e6, 0);
        vm.stopPrank();

        vm.startPrank(trader2);
        baseToken.approve(address(market), 200e6);
        market.buyOutcome(2, 200e6, 0);
        vm.stopPrank();

        uint256 priceYes = market.getPrice(1);
        uint256 priceNo = market.getPrice(2);
        assertApproxEqAbs(priceYes + priceNo, 1e18, 1);
    }

    function test_RemoveLiquidityRevertsInsufficientShares() public {
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.InsufficientShares.selector));
        vm.prank(trader);
        market.removeLiquidity(1);
    }

    function test_ConstructorRevertsHighFee() public {
        vm.expectRevert(abi.encodeWithSelector(PredictionMarket.FeeTooHigh.selector));
        new PredictionMarket(
            "test", resolutionTime, disputeWindow,
            address(ot), yesId, noId,
            address(baseToken), 1001,
            address(feeVaultProxy), address(priceFeed), resolver
        );
    }

    function test_RedeemFullWinningPool() public {
        vm.startPrank(lp);
        baseToken.approve(address(market), 1000e6);
        market.addLiquidity(1000e6);
        vm.stopPrank();

        vm.startPrank(trader);
        baseToken.approve(address(market), 500e6);
        market.buyOutcome(1, 500e6, 0);
        uint256 traderYes = ot.balanceOf(trader, yesId);
        vm.stopPrank();

        vm.warp(resolutionTime);
        vm.prank(resolver);
        market.resolveMarket(1);

        vm.startPrank(trader);
        ot.setApprovalForAll(address(market), true);
        uint256 balBefore = baseToken.balanceOf(trader);
        market.redeem(1);
        vm.stopPrank();

        assertTrue(baseToken.balanceOf(trader) > balBefore);
    }
}
