pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../../src/core/FeeVault.sol";
import "../../src/mock/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultInvariantTest is StdInvariant, Test {
    FeeVault public vault;
    MockUSDC public asset;

    address public user1 = address(0x100);
    address public user2 = address(0x200);

    function setUp() public {
        asset = new MockUSDC();
        FeeVault impl = new FeeVault();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeWithSelector(FeeVault.initialize.selector, address(asset), address(this)));
        vault = FeeVault(address(proxy));

        asset.mint(user1, 1_000_000e6);
        asset.mint(user2, 1_000_000e6);

        vm.startPrank(user1);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(100_000e6, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(200_000e6, user2);
        vm.stopPrank();
    }

    function invariant_totalAssetsEqualsSum() public {
        uint256 ta = vault.totalAssets();
        uint256 totalDeposited = 300_000e6;
        assertEq(ta, totalDeposited, "Total assets should equal deposits");
    }

    function invariant_sharesReflectDeposits() public {
        uint256 totalShares = vault.totalSupply();
        uint256 user1Shares = vault.balanceOf(user1);
        uint256 user2Shares = vault.balanceOf(user2);
        assertEq(totalShares, user1Shares + user2Shares, "Shares should sum");
    }
}
