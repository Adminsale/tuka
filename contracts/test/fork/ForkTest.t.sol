pragma solidity ^0.8.23;

import "forge-std/Test.sol";

contract ForkTest is Test {
    address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function test_ChainlinkFeedOnMainnet() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;

        vm.createSelectFork(rpcUrl);

        address feedAddr = CHAINLINK_ETH_USD;
        (bool success, bytes memory data) = feedAddr.staticcall(
            abi.encodeWithSignature("latestRoundData()")
        );
        require(success, "Chainlink call failed");
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            abi.decode(data, (uint80, int256, uint256, uint256, uint80));

        assertTrue(answer > 0, "ETH price should be positive");
        assertTrue(updatedAt > 0, "Should have recent timestamp");
        assertTrue(answeredInRound >= roundId, "Round should be complete");
    }

    function test_GetUsdcBalanceMainnet() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;

        vm.createSelectFork(rpcUrl);

        (, bytes memory data) = USDC_MAINNET.call(
            abi.encodeWithSignature("balanceOf(address)", 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503)
        );
        uint256 balance = abi.decode(data, (uint256));
        assertTrue(balance > 0, "USDC balance should exist");
    }

    function test_UsdcDecimalsMainnet() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;

        vm.createSelectFork(rpcUrl);

        (, bytes memory data) = USDC_MAINNET.call(
            abi.encodeWithSignature("decimals()")
        );
        uint8 dec = abi.decode(data, (uint8));
        assertEq(dec, 6, "USDC should have 6 decimals");
    }
}
