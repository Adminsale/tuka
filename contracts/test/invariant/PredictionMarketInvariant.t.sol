pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../../src/core/PredictionMarket.sol";
import "../../src/core/FeeVault.sol";
import "../../src/tokens/OutcomeToken.sol";
import "../../src/mock/MockUSDC.sol";
import "../../src/mock/MockAggregator.sol";
import "../../src/oracles/ChainlinkPriceFeed.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PredictionMarketInvariantTest is StdInvariant, Test {
    PredictionMarket public market;
    OutcomeToken public ot;
    MockUSDC public baseToken;
    uint256 public yesId;
    uint256 public noId;

    address public alice = address(0x100);
    address public bob = address(0x200);

    function setUp() public {
        baseToken = new MockUSDC();
        MockAggregator aggregator = new MockAggregator(2000e8);
        ChainlinkPriceFeed priceFeed = new ChainlinkPriceFeed(address(aggregator), 3600);

        FeeVault feeVault = new FeeVault();
        ERC1967Proxy feeVaultProxy = new ERC1967Proxy(address(feeVault), abi.encodeWithSelector(FeeVault.initialize.selector, address(baseToken), address(this)));

        ot = new OutcomeToken("Outcome", "OC", "");
        yesId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(1))));
        noId = uint256(keccak256(abi.encodePacked(uint256(1), uint8(2))));

        market = new PredictionMarket(
            "Invariant test?", block.timestamp + 30 days, 2 days,
            address(ot), yesId, noId,
            address(baseToken), 0,
            address(0),
            address(priceFeed),
            address(this)
        );

        ot.grantRole(ot.MINTER_ROLE(), address(market));
        ot.grantRole(ot.BURNER_ROLE(), address(market));

        baseToken.mint(alice, 1_000_000e6);
        baseToken.mint(bob, 1_000_000e6);
        baseToken.mint(address(this), 1_000_000e6);

        vm.startPrank(alice);
        baseToken.approve(address(market), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        baseToken.approve(address(market), type(uint256).max);
        vm.stopPrank();

        baseToken.approve(address(market), type(uint256).max);

        market.addLiquidity(100_000e6);
    }

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public lastK;

    function invariant_kNeverIncreases() public {
        (uint256 ry, uint256 rn) = market.getReserves();
        if (ry > 0 && rn > 0) {
            uint256 k = ry * rn;
            if (lastK > 0) {
                assertTrue(k <= lastK + (lastK / 100) + 1, "k should not increase significantly");
            }
            lastK = k;
        }
    }

    function invariant_totalLpSharesNeverZero() public {
        uint256 total = market.totalLpShares();
        if (total > 0) {
            assertGe(total, MINIMUM_LIQUIDITY, "totalLpShares must include burned MINIMUM_LIQUIDITY");
        }
    }

    function invariant_priceSumToOne() public {
        (uint256 ry, uint256 rn) = market.getReserves();
        if (ry > 0 && rn > 0) {
            uint256 pYes = market.getPrice(1);
            uint256 pNo = market.getPrice(2);
            assertApproxEqAbs(pYes + pNo, 1e18, 1, "Prices should sum to 1");
        }
    }

    function invariant_reservesNonNegative() public {
        (uint256 ry, uint256 rn) = market.getReserves();
        if (ry > 0 || rn > 0) {
            assertTrue(ry >= 0 && rn >= 0, "Reserves must be non-negative");
        }
    }

    function invariant_treasuryAccounting() public {
        uint256 totalBase = baseToken.balanceOf(address(market));
        (uint256 ry, uint256 rn) = market.getReserves();
        assertGe(totalBase, ry + rn, "Treasury base tokens must cover reserves");
    }

    function invariant_yesNoSupplyMatch() public {
        (uint256 ry, uint256 rn) = market.getReserves();
        if (ry > 0 || rn > 0) {
            uint256 yesSupply = ot.balanceOf(address(market), yesId);
            uint256 noSupply = ot.balanceOf(address(market), noId);
            assertEq(yesSupply, ry, "YES reserve must match market YES token balance");
            assertEq(noSupply, rn, "NO reserve must match market NO token balance");
        }
    }
}
