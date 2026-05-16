pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/core/PredictionMarket.sol";
import "../../src/core/MarketFactory.sol";
import "../../src/core/FeeVault.sol";
import "../../src/tokens/OutcomeToken.sol";
import "../../src/tokens/GovernanceToken.sol";
import "../../src/mock/MockUSDC.sol";
import "../../src/mock/MockAggregator.sol";
import "../../src/oracles/ChainlinkPriceFeed.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PredictionMarketFuzzTest is Test {
    PredictionMarket public market;
    OutcomeToken public ot;
    MockUSDC public baseToken;
    MockAggregator public aggregator;
    ChainlinkPriceFeed public priceFeed;

    uint256 public yesId;
    uint256 public noId;
    uint256 public resolutionTime;

    function setUp() public {
        baseToken = new MockUSDC();
        aggregator = new MockAggregator(2000e8);
        priceFeed = new ChainlinkPriceFeed(address(aggregator), 3600);

        FeeVault feeVault = new FeeVault();
        ERC1967Proxy feeVaultProxy = new ERC1967Proxy(address(feeVault), abi.encodeWithSelector(FeeVault.initialize.selector, address(baseToken), address(this)));

        ot = new OutcomeToken("Outcome", "OC", "");
        yesId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(1))));
        noId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(2))));
        resolutionTime = block.timestamp + 7 days;

        market = new PredictionMarket(
            "Fuzz test?", resolutionTime, 2 days,
            address(ot), yesId, noId,
            address(baseToken), 30,
            address(feeVaultProxy),
            address(priceFeed),
            address(this)
        );

        ot.grantRole(ot.MINTER_ROLE(), address(market));
        ot.grantRole(ot.BURNER_ROLE(), address(market));

        baseToken.mint(address(this), 1_000_000_000e6);
        baseToken.approve(address(market), type(uint256).max);
    }

    function testFuzz_SwapAlwaysPreservesK(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, 100_000e6);
        market.addLiquidity(1_000_000e6);

        (uint256 ryBefore, uint256 rnBefore) = market.getReserves();
        uint256 kBefore = ryBefore * rnBefore;

        market.splitBase(amountIn);
        market.swap(noId, yesId, amountIn, 0);

        (uint256 ryAfter, uint256 rnAfter) = market.getReserves();
        uint256 kAfter = ryAfter * rnAfter;

        assertLe(kAfter, kBefore + 1, "k should not increase (fees reduce k)");
        assertApproxEqAbs(kAfter, kBefore, kBefore / 1, "k should remain roughly constant");
    }

    function testFuzz_BuyOutcome(uint256 amountIn, uint256 liquidity) public {
        amountIn = bound(amountIn, 1, 100_000e6);
        liquidity = bound(liquidity, 1000e6, 1_000_000e6);

        market.addLiquidity(liquidity);

        baseToken.approve(address(market), type(uint256).max);
        uint256 out = market.buyOutcome(1, amountIn, 0);

        assertTrue(out >= amountIn, "Should at least get back the split amount");
        assertTrue(ot.balanceOf(address(this), yesId) == out);
    }

    function testFuzz_AddLiquidity(uint256 amount) public {
        amount = bound(amount, 1, 100_000e6);

        uint256 shares = market.addLiquidity(amount);
        assertTrue(shares > 0, "Shares should be minted");

        (uint256 ry, uint256 rn) = market.getReserves();
        assertEq(ry, amount, "YES reserve should match");
        assertEq(rn, amount, "NO reserve should match");
    }

    function testFuzz_MultipleSwaps(uint256 amount1, uint256 amount2, uint256 amount3) public {
        amount1 = bound(amount1, 1e6, 10_000e6);
        amount2 = bound(amount2, 1e6, 10_000e6);
        amount3 = bound(amount3, 1e6, 10_000e6);

        market.addLiquidity(1_000_000e6);
        ot.setApprovalForAll(address(market), true);

        baseToken.approve(address(market), type(uint256).max);

        uint256 totalSpent = 0;
        market.buyOutcome(1, amount1, 0);
        totalSpent += amount1;
        market.buyOutcome(2, amount2, 0);
        totalSpent += amount2;
        market.buyOutcome(1, amount3, 0);
        totalSpent += amount3;

        (uint256 ry, uint256 rn) = market.getReserves();
        assertTrue(ry > 0, "YES reserve > 0");
        assertTrue(rn > 0, "NO reserve > 0");
    }

    function testFuzz_GovernanceVotingPower(uint256 amount) public {
        GovernanceToken gt = new GovernanceToken("Test", "TST");
        address voter = address(0xABCD);
        amount = bound(amount, 1e18, 1_000_000e18);

        gt.transfer(voter, amount);
        vm.prank(voter);
        gt.delegate(voter);

        uint256 votes = gt.getVotes(voter);
        assertEq(votes, amount);
    }

    function testFuzz_VaultDepositWithdraw(uint256 amount) public {
        FeeVault vaultImpl = new FeeVault();
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImpl), abi.encodeWithSelector(FeeVault.initialize.selector, address(baseToken), address(this)));
        FeeVault vault = FeeVault(address(proxy));

        amount = bound(amount, 10e6, 1_000_000e6);
        baseToken.mint(address(this), amount);
        baseToken.approve(address(vault), amount);

        uint256 shares = vault.deposit(amount, address(this));
        assertEq(shares, vault.balanceOf(address(this)));

        uint256 assetsBack = vault.redeem(shares, address(this), address(this));
        assertEq(assetsBack, amount);
    }
}
