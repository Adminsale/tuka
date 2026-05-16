pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/mock/MockUSDC.sol";
import "../src/mock/MockAggregator.sol";
import "../src/tokens/GovernanceToken.sol";
import "../src/tokens/OutcomeToken.sol";
import "../src/core/MarketFactory.sol";
import "../src/core/PredictionMarket.sol";
import "../src/core/FeeVault.sol";
import "../src/core/FeeVaultV2.sol";
import "../src/governance/ProtocolGovernor.sol";
import "../src/oracles/ChainlinkPriceFeed.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    address public constant CHAINLINK_ETH_USD_FEED = 0x0000000000000000000000000000000000000000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mockUSDC = new MockUSDC();
        MockAggregator mockAgg = new MockAggregator(2000e8);

        GovernanceToken govToken = new GovernanceToken("Prediction Market Governance", "pGOV");

        TimelockController timelock = new TimelockController(
            2 days,
            new address[](0),
            new address[](0),
            deployer
        );

        ProtocolGovernor governor = new ProtocolGovernor(
            IVotes(address(govToken)),
            timelock
        );

        ChainlinkPriceFeed priceFeed = new ChainlinkPriceFeed(
            address(mockAgg),
            3600
        );

        FeeVault feeVaultImpl = new FeeVault();
        ERC1967Proxy feeVaultProxy = new ERC1967Proxy(
            address(feeVaultImpl),
            abi.encodeWithSelector(
                FeeVault.initialize.selector,
                address(mockUSDC),
                address(timelock)
            )
        );

        OutcomeToken outcomeImpl = new OutcomeToken("Outcome", "OC", "");

        PredictionMarket marketImpl = new PredictionMarket(
            "", 0, 0,
            address(0), 0, 0,
            address(0), 0, address(0), address(0), address(0)
        );

        MarketFactory factory = new MarketFactory(
            address(outcomeImpl),
            address(marketImpl),
            address(mockUSDC),
            address(feeVaultProxy),
            address(priceFeed),
            30,
            2 days
        );

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));

        bytes32 adminRole = govToken.DEFAULT_ADMIN_ROLE();
        govToken.grantRole(adminRole, address(timelock));
        govToken.revokeRole(adminRole, deployer);

        mockUSDC.mint(address(feeVaultProxy), 100_000e6);

        vm.stopBroadcast();

        _writeDeployment(deployer, address(mockUSDC), address(mockAgg), address(govToken),
            address(timelock), address(governor), address(priceFeed),
            address(feeVaultProxy), address(feeVaultImpl), address(factory), address(marketImpl));
    }

    function _writeDeployment(
        address deployer,
        address mockUSDC,
        address mockAgg,
        address govToken,
        address timelock,
        address governor,
        address priceFeed,
        address feeVaultProxy,
        address feeVaultImpl,
        address factory,
        address marketImpl
    ) internal {
        string memory json = "{";
        json = string.concat(json, '"deployer": "', vm.toString(deployer), '",');
        json = string.concat(json, '"mockUSDC": "', vm.toString(mockUSDC), '",');
        json = string.concat(json, '"mockAggregator": "', vm.toString(mockAgg), '",');
        json = string.concat(json, '"governanceToken": "', vm.toString(govToken), '",');
        json = string.concat(json, '"timelockController": "', vm.toString(timelock), '",');
        json = string.concat(json, '"protocolGovernor": "', vm.toString(governor), '",');
        json = string.concat(json, '"chainlinkPriceFeed": "', vm.toString(priceFeed), '",');
        json = string.concat(json, '"feeVaultProxy": "', vm.toString(feeVaultProxy), '",');
        json = string.concat(json, '"feeVaultImpl": "', vm.toString(feeVaultImpl), '",');
        json = string.concat(json, '"marketFactory": "', vm.toString(factory), '",');
        json = string.concat(json, '"marketImpl": "', vm.toString(marketImpl), '"');
        json = string.concat(json, "}");

        vm.writeJson(json, "deployments/deployment.json");
    }
}

contract DeployL2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mockUSDC = new MockUSDC();
        MockAggregator mockAgg = new MockAggregator(2000e8);

        GovernanceToken govToken = new GovernanceToken("Prediction Market Governance", "pGOV");

        TimelockController timelock = new TimelockController(
            2 days,
            new address[](0),
            new address[](0),
            deployer
        );

        ProtocolGovernor governor = new ProtocolGovernor(
            IVotes(address(govToken)),
            timelock
        );

        ChainlinkPriceFeed priceFeed = new ChainlinkPriceFeed(
            address(mockAgg),
            3600
        );

        FeeVault feeVaultImpl = new FeeVault();
        ERC1967Proxy feeVaultProxy = new ERC1967Proxy(
            address(feeVaultImpl),
            abi.encodeWithSelector(FeeVault.initialize.selector, address(mockUSDC), address(timelock))
        );

        PredictionMarket marketImpl = new PredictionMarket(
            "", 0, 0, address(0), 0, 0, address(0), 0, address(0), address(0), address(0)
        );

        OutcomeToken outcomeImpl = new OutcomeToken("Outcome", "OC", "");

        MarketFactory factory = new MarketFactory(
            address(outcomeImpl),
            address(marketImpl),
            address(mockUSDC),
            address(feeVaultProxy),
            address(priceFeed),
            30,
            2 days
        );

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));

        govToken.grantRole(govToken.DEFAULT_ADMIN_ROLE(), address(timelock));
        govToken.revokeRole(govToken.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();

        _writeL2Deployment(deployer, address(mockUSDC), address(govToken),
            address(timelock), address(governor), address(priceFeed),
            address(feeVaultProxy), address(factory));
    }

    function _writeL2Deployment(
        address deployer,
        address mockUSDC,
        address govToken,
        address timelock,
        address governor,
        address priceFeed,
        address feeVaultProxy,
        address factory
    ) internal {
        string memory chain = vm.envOr("CHAIN_NAME", string("unknown"));
        string memory json = "{";
        json = string.concat(json, '"chain": "', chain, '",');
        json = string.concat(json, '"deployer": "', vm.toString(deployer), '",');
        json = string.concat(json, '"mockUSDC": "', vm.toString(mockUSDC), '",');
        json = string.concat(json, '"governanceToken": "', vm.toString(govToken), '",');
        json = string.concat(json, '"timelockController": "', vm.toString(timelock), '",');
        json = string.concat(json, '"protocolGovernor": "', vm.toString(governor), '",');
        json = string.concat(json, '"chainlinkPriceFeed": "', vm.toString(priceFeed), '",');
        json = string.concat(json, '"feeVaultProxy": "', vm.toString(feeVaultProxy), '",');
        json = string.concat(json, '"marketFactory": "', vm.toString(factory), '"');
        json = string.concat(json, "}");

        vm.writeJson(json, string.concat("deployments/deployment_", chain, ".json"));
    }
}

contract UpgradeVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("FEE_VAULT_PROXY");
        vm.startBroadcast(deployerPrivateKey);

        FeeVaultV2 newImpl = new FeeVaultV2();
        FeeVault(address(payable(proxyAddress))).upgradeToAndCall(address(newImpl), "");

        FeeVaultV2(address(payable(proxyAddress))).initializeV2(10);

        vm.stopBroadcast();
    }
}

contract VerifyDeployment is Script {
    function run() external {
        address timelock = vm.envAddress("TIMELOCK");
        address governor = vm.envAddress("GOVERNOR");
        address factory = vm.envAddress("FACTORY");
        address feeVault = vm.envAddress("FEE_VAULT");
        address govToken = vm.envAddress("GOV_TOKEN");

        TimelockController tl = TimelockController(payable(timelock));
        require(tl.getMinDelay() == 2 days, "Timelock delay mismatch");
        require(tl.hasRole(tl.PROPOSER_ROLE(), governor), "Governor not proposer");
        require(tl.hasRole(tl.EXECUTOR_ROLE(), governor), "Governor not executor");
        require(!tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), msg.sender), "Deployer still admin");
        require(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), timelock), "Timelock not self-admin");

        ProtocolGovernor g = ProtocolGovernor(payable(governor));
        require(g.votingDelay() == 1 days, "Voting delay mismatch");
        require(g.votingPeriod() == 1 weeks, "Voting period mismatch");

        MarketFactory f = MarketFactory(factory);
        require(f.isMarket(address(0)) == false, "Factory has ghost market");

        console.log("All verifications passed");
    }
}
