pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/core/PredictionMarket.sol";
import "../../src/core/FeeVault.sol";
import "../../src/tokens/OutcomeToken.sol";
import "../../src/tokens/GovernanceToken.sol";
import "../../src/mock/MockUSDC.sol";
import "../../src/mock/MockAggregator.sol";
import "../../src/oracles/ChainlinkPriceFeed.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ExtendedFuzzTests is Test {
    PredictionMarket public market;
    OutcomeToken public ot;
    MockUSDC public baseToken;
    uint256 public yesId;
    uint256 public noId;

    function setUp() public {
        baseToken = new MockUSDC();
        MockAggregator aggregator = new MockAggregator(2000e8);
        ChainlinkPriceFeed priceFeed = new ChainlinkPriceFeed(address(aggregator), 3600);

        FeeVault feeVault = new FeeVault();
        ERC1967Proxy feeVaultProxy = new ERC1967Proxy(address(feeVault), abi.encodeWithSelector(FeeVault.initialize.selector, address(baseToken), address(this)));

        ot = new OutcomeToken("Outcome", "OC", "");
        yesId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(1))));
        noId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(2))));

        market = new PredictionMarket("Fuzz Test", block.timestamp + 7 days, 2 days,
            address(ot), yesId, noId, address(baseToken), 30, address(feeVaultProxy), address(priceFeed), address(this));

        ot.grantRole(ot.MINTER_ROLE(), address(market));
        ot.grantRole(ot.BURNER_ROLE(), address(market));

        baseToken.mint(address(this), 10_000_000e6);
        baseToken.approve(address(market), type(uint256).max);
        ot.setApprovalForAll(address(market), true);

        market.addLiquidity(1_000_000e6);
    }

    function testFuzz_SellOutcome(uint256 amount) public {
        amount = bound(amount, 1e3, 10_000e6);
        market.buyOutcome(1, amount, 0);
        uint256 balance = ot.balanceOf(address(this), yesId);
        uint256 out = market.sellOutcome(1, balance, 0);
        assertTrue(out > 0);
    }

    function testFuzz_RemoveLiquidity(uint256 amount) public {
        amount = bound(amount, 1000e6, 500_000e6);
        uint256 shares = market.addLiquidity(amount);
        (uint256 ay, uint256 an) = market.removeLiquidity(shares);
        assertTrue(ay > 0);
        assertTrue(an > 0);
    }

    function testFuzz_SplitAndMerge(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000e6);
        market.splitBase(amount);
        assertEq(ot.balanceOf(address(this), yesId), amount);
        assertEq(ot.balanceOf(address(this), noId), amount);
        market.mergeOutcomes(amount);
        assertEq(ot.balanceOf(address(this), yesId), 0);
        assertEq(ot.balanceOf(address(this), noId), 0);
    }

    function testFuzz_VaultMint(uint256 amount) public {
        amount = bound(amount, 100e6, 1_000_000e6);
        FeeVault v = new FeeVault();
        ERC1967Proxy p = new ERC1967Proxy(address(v), abi.encodeWithSelector(FeeVault.initialize.selector, address(baseToken), address(this)));
        FeeVault vault = FeeVault(address(p));

        baseToken.approve(address(vault), amount);
        uint256 shares = vault.mint(amount / 10, address(this));
        assertTrue(shares > 0);
    }

    function testFuzz_GovernanceProposalThreshold(uint256 transferAmount) public {
        GovernanceToken gt = new GovernanceToken("Test", "TST");
        address proposer = address(0xABCD);
        transferAmount = bound(transferAmount, 1e18, 100_000e18);
        gt.transfer(proposer, transferAmount);
        vm.prank(proposer);
        gt.delegate(proposer);
        assertEq(gt.getVotes(proposer), transferAmount);
    }
}
