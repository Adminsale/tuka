pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/tokens/GovernanceToken.sol";
import "../../src/governance/ProtocolGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceTest is Test {
    GovernanceToken public govToken;
    TimelockController public timelock;
    ProtocolGovernor public governor;

    address public deployer = address(0x1);
    address public voter1 = address(0x2);
    address public voter2 = address(0x3);
    address public treasury = address(0x4);

    function setUp() public {
        vm.startPrank(deployer);
        govToken = new GovernanceToken("Gov", "GOV");

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(2 days, proposers, executors, deployer);

        governor = new ProtocolGovernor(IVotes(address(govToken)), timelock);

        govToken.transfer(voter1, 100_000e18);
        govToken.transfer(voter2, 100_000e18);
        vm.stopPrank();

        vm.startPrank(voter1);
        govToken.delegate(voter1);
        vm.stopPrank();

        vm.startPrank(voter2);
        govToken.delegate(voter2);
        vm.stopPrank();
    }

    function test_GovernanceToken() public {
        assertEq(govToken.name(), "Gov");
        assertEq(govToken.symbol(), "GOV");
        assertEq(govToken.decimals(), 18);
    }

    function test_GovernanceTokenPermit() public {
        (address alice, uint256 aliceKey) = makeAddrAndKey("alice");
        govToken.transfer(alice, 100e18);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, keccak256(abi.encodePacked(
            "\x19\x01",
            govToken.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice, address(0x42), 50e18, 0, block.timestamp + 1 hours
            ))
        )));
        govToken.permit(alice, address(0x42), 50e18, block.timestamp + 1 hours, v, r, s);
        assertEq(govToken.allowance(alice, address(0x42)), 50e18);
    }

    function test_Delegation() public {
        vm.prank(voter1);
        govToken.delegate(voter1);
        assertEq(govToken.delegates(voter1), voter1);
        assertEq(govToken.getVotes(voter1), 100_000e18);
    }

    function test_VotingPowerAfterTransfer() public {
        uint256 votesBefore = govToken.getVotes(voter1);
        vm.prank(voter1);
        govToken.transfer(voter2, 10_000e18);
        assertTrue(govToken.getVotes(voter1) < votesBefore);
    }

    function test_GovernorInitialState() public {
        assertEq(uint256(governor.votingDelay()), 1 days / 1); // 1 day
        assertEq(uint256(governor.votingPeriod()), 1 weeks / 1); // 1 week
    }

    function test_Propose() public {
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = address(treasury);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("receive()");
        string memory description = "Test proposal";

        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertTrue(proposalId > 0);
    }

    function test_ProposeRevertsBelowThreshold() public {
        address poorVoter = address(0x5);
        govToken.transfer(poorVoter, 1e18);
        vm.prank(poorVoter);
        govToken.delegate(poorVoter);

        address[] memory targets = new address[](1);
        targets[0] = address(0xdead);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Poor proposal";

        vm.expectRevert();
        vm.prank(poorVoter);
        governor.propose(targets, values, calldatas, description);
    }

    function test_ProposeVoteQueueExecute() public {
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = address(0xdead);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("receive()");
        string memory description = "Full lifecycle test";

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 votesFor = govToken.getVotes(voter1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        bytes32 descHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descHash);

        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(targets, values, calldatas, descHash);
    }
}
