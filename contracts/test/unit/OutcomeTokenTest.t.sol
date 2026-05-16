pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/tokens/OutcomeToken.sol";

contract OutcomeTokenTest is Test {
    OutcomeToken public ot;
    address public admin = address(0x1);
    address public minter = address(0x2);
    address public burner = address(0x3);
    address public user = address(0x4);

    uint256 public tokenId = 1;

    function setUp() public {
        ot = new OutcomeToken("Outcome Token", "OT", "https://api.example.com/");
        ot.grantRole(ot.MINTER_ROLE(), minter);
        ot.grantRole(ot.BURNER_ROLE(), burner);
    }

    function test_InitialState() public {
        assertEq(ot.name(), "Outcome Token");
        assertEq(ot.symbol(), "OT");
        assertEq(ot.uri(tokenId), "https://api.example.com/");
    }

    function test_Mint() public {
        vm.prank(minter);
        ot.mint(user, tokenId, 100, "");
        assertEq(ot.balanceOf(user, tokenId), 100);
    }

    function test_MintRevertsWithoutRole() public {
        vm.prank(user);
        vm.expectRevert();
        ot.mint(user, tokenId, 100, "");
    }

    function test_Burn() public {
        vm.prank(minter);
        ot.mint(user, tokenId, 100, "");
        vm.prank(burner);
        ot.burn(user, tokenId, 40);
        assertEq(ot.balanceOf(user, tokenId), 60);
    }

    function test_BurnRevertsWithoutRole() public {
        vm.prank(minter);
        ot.mint(user, tokenId, 100, "");
        vm.prank(user);
        vm.expectRevert();
        ot.burn(user, tokenId, 40);
    }

    function test_MintBatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1; ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100; amounts[1] = 200;

        vm.prank(minter);
        ot.mintBatch(user, ids, amounts, "");
        assertEq(ot.balanceOf(user, 1), 100);
        assertEq(ot.balanceOf(user, 2), 200);
    }

    function test_BurnBatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1; ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100; amounts[1] = 200;

        vm.prank(minter);
        ot.mintBatch(user, ids, amounts, "");
        vm.prank(burner);
        ot.burnBatch(user, ids, amounts);
        assertEq(ot.balanceOf(user, 1), 0);
        assertEq(ot.balanceOf(user, 2), 0);
    }

    function test_SetUri() public {
        ot.setURI("https://new-uri.com/");
        assertEq(ot.uri(tokenId), "https://new-uri.com/");
    }

    function test_SupportsInterface() public {
        assertTrue(ot.supportsInterface(0xd9b67a26));
        assertTrue(ot.supportsInterface(0x01ffc9a7));
    }
}
