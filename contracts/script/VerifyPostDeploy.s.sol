pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/governance/ProtocolGovernor.sol";
import "../src/core/MarketFactory.sol";

contract VerifyPostDeploy is Script {
    function run() external {
        address timelock = vm.envAddress("TIMELOCK");
        address governor = vm.envAddress("GOVERNOR");
        address factory = vm.envAddress("FACTORY");
        address feeVault = vm.envAddress("FEE_VAULT");
        address govToken = vm.envAddress("GOV_TOKEN");

        console.log("=== Post-Deployment Verification ===");
        console.log("Timelock:", timelock);
        console.log("Governor:", governor);
        console.log("Factory:", factory);
        console.log("FeeVault:", feeVault);
        console.log("GovToken:", govToken);

        TimelockController tl = TimelockController(payable(timelock));
        require(tl.getMinDelay() == 2 days, "FAIL: Timelock delay != 2 days");
        console.log("PASS: Timelock delay = 2 days");

        require(tl.hasRole(tl.PROPOSER_ROLE(), governor), "FAIL: Governor is not proposer");
        require(tl.hasRole(tl.EXECUTOR_ROLE(), governor), "FAIL: Governor is not executor");
        console.log("PASS: Governor is proposer/executor on timelock");

        require(!tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), msg.sender), "FAIL: Deployer is still timelock admin");
        require(tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), timelock), "FAIL: Timelock is not self-admin");
        console.log("PASS: No admin backdoor");

        ProtocolGovernor g = ProtocolGovernor(payable(governor));
        require(g.votingDelay() == 1 days, "FAIL: Voting delay != 1 day");
        require(g.votingPeriod() == 1 weeks, "FAIL: Voting period != 1 week");
        console.log("PASS: Governor parameters match spec");

        MarketFactory f = MarketFactory(factory);
        require(f.getMarketCount() == 0, "FAIL: Factory should have 0 markets");
        console.log("PASS: Factory initialized with 0 markets");

        console.log("=== ALL VERIFICATIONS PASSED ===");
    }
}
