pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/oracles/ChainlinkPriceFeed.sol";
import "../../src/mock/MockAggregator.sol";

contract OracleTest is Test {
    MockAggregator public agg;
    ChainlinkPriceFeed public feed;

    function setUp() public {
        agg = new MockAggregator(2000e8);
        feed = new ChainlinkPriceFeed(address(agg), 3600);
    }

    function test_GetPrice() public {
        uint256 price = feed.getPrice();
        assertEq(price, 2000e8);
    }

    function test_StalenessCheck() public {
        vm.warp(block.timestamp + 3601);
        vm.expectRevert("ChainlinkPriceFeed: price is stale");
        feed.getPrice();
    }

    function test_PriceNotPositive() public {
        agg.setAnswer(-1);
        vm.expectRevert("ChainlinkPriceFeed: price is not positive");
        feed.getPrice();
    }

    function test_Decimals() public {
        assertEq(feed.decimals(), 8);
    }

    function test_SetAggregator() public {
        MockAggregator newAgg = new MockAggregator(3000e8);
        feed.setAggregator(address(newAgg));
        uint256 price = feed.getPrice();
        assertEq(price, 3000e8);
    }

    function test_SetAggregatorOnlyOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        feed.setAggregator(address(0));
    }

    function test_SetStalenessThreshold() public {
        feed.setStalenessThreshold(7200);
        vm.warp(block.timestamp + 4000);
        uint256 price = feed.getPrice();
        assertEq(price, 2000e8);
    }

    function test_StaleAfterCustomThreshold() public {
        feed.setStalenessThreshold(100);
        vm.warp(block.timestamp + 200);
        vm.expectRevert("ChainlinkPriceFeed: price is stale");
        feed.getPrice();
    }
}
