pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/core/MarketFactory.sol";
import "../../src/core/PredictionMarket.sol";
import "../../src/core/FeeVault.sol";
import "../../src/tokens/OutcomeToken.sol";
import "../../src/mock/MockUSDC.sol";
import "../../src/mock/MockAggregator.sol";
import "../../src/oracles/ChainlinkPriceFeed.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MarketFactoryTest is Test {
    MarketFactory public factory;
    MockUSDC public baseToken;
    MockAggregator public aggregator;
    ChainlinkPriceFeed public priceFeed;
    FeeVault public feeVault;
    ERC1967Proxy public feeVaultProxy;

    address public admin = address(0x1);

    function setUp() public {
        baseToken = new MockUSDC();
        aggregator = new MockAggregator(2000e8);
        priceFeed = new ChainlinkPriceFeed(address(aggregator), 3600);

        feeVault = new FeeVault();
        feeVaultProxy = new ERC1967Proxy(address(feeVault), abi.encodeWithSelector(FeeVault.initialize.selector, address(baseToken), admin));

        OutcomeToken outcomeImpl = new OutcomeToken("Outcome", "OC", "");
        PredictionMarket marketImpl = new PredictionMarket("", 0, 0, address(0), 0, 0, address(0), 0, address(0), address(0), address(0));

        factory = new MarketFactory(
            address(outcomeImpl),
            address(marketImpl),
            address(baseToken),
            address(feeVaultProxy),
            address(priceFeed),
            30,
            2 days
        );
    }

    function test_DeployMarket() public {
        uint256 resolutionTime = block.timestamp + 7 days;
        address market = factory.deployMarket("Will ETH hit $10k?", resolutionTime);

        assertTrue(market != address(0));
        assertEq(factory.marketCount(), 1);
        assertTrue(factory.isMarket(market));

        PredictionMarket pm = PredictionMarket(payable(market));
        assertEq(pm.question(), "Will ETH hit $10k?");
        assertEq(address(pm.baseToken()), address(baseToken));
    }

    function test_DeployMultipleMarkets() public {
        uint256 resTime = block.timestamp + 7 days;
        address m1 = factory.deployMarket("Market 1", resTime);
        address m2 = factory.deployMarket("Market 2", resTime);
        address m3 = factory.deployMarket("Market 3", resTime);

        assertEq(factory.marketCount(), 3);
        assertTrue(factory.isMarket(m1));
        assertTrue(factory.isMarket(m2));
        assertTrue(factory.isMarket(m3));
    }

    function test_DeployDeterministic() public {
        uint256 resolutionTime = block.timestamp + 7 days;
        bytes32 salt = keccak256("test-salt");

        address predicted = factory.getDeployAddress(
            keccak256(abi.encodePacked(salt, uint256(1)))
        );
        address market = factory.deployMarketDeterministic("Deterministic Market", resolutionTime, salt);

        assertEq(market, predicted);
        assertTrue(factory.isMarket(market));
    }

    function test_GetMarkets() public {
        uint256 resTime = block.timestamp + 7 days;
        factory.deployMarket("M1", resTime);
        factory.deployMarket("M2", resTime);
        factory.deployMarket("M3", resTime);

        address[] memory mkts = factory.getMarkets(0, 2);
        assertEq(mkts.length, 2);
    }

    function test_DeployedMarketHasCorrectRoles() public {
        uint256 resTime = block.timestamp + 7 days;
        address marketAddr = factory.deployMarket("Test Market", resTime);
        PredictionMarket pm = PredictionMarket(payable(marketAddr));

        assertTrue(pm.hasRole(pm.MANAGER_ROLE(), admin));
        assertTrue(pm.hasRole(pm.RESOLVER_ROLE(), address(this)));
        assertTrue(pm.hasRole(pm.DEFAULT_ADMIN_ROLE(), address(factory)));
    }

    function test_DeployedMarketHasOutcomeTokens() public {
        uint256 resTime = block.timestamp + 7 days;
        address marketAddr = factory.deployMarket("Test", resTime);
        PredictionMarket pm = PredictionMarket(payable(marketAddr));

        OutcomeToken ot = pm.outcomeToken();
        assertTrue(address(ot) != address(0));
        assertTrue(ot.hasRole(ot.MINTER_ROLE(), marketAddr));
        assertTrue(ot.hasRole(ot.BURNER_ROLE(), marketAddr));
    }
}
