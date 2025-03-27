// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DiamondUtils} from "./helpers/DiamondUtils.sol";
import {ERC20Facet} from "../contracts/facets/ERC20Facet.sol";

contract ERC20FacetTest is DiamondUtils {
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    function setUp() public {
        deployDiamond();
        erc20Facet = ERC20Facet(address(diamond));
    }




    function testTransfer() public {
        // Assuming the contract deployer has initial balance
        vm.startPrank(address(this));
        erc20Facet.mint(user1, 500);
        vm.stopPrank();

        
        assertEq(erc20Facet.balanceOf(user1), 500);
    }

    function test_RevertWhen_TransferWithInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        erc20Facet.transfer(user2, 100);
        vm.stopPrank();
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        vm.startPrank(user1);
        vm.expectRevert("ERC20: transfer to the zero address");
        erc20Facet.transfer(address(0), 100);
        vm.stopPrank();
    }

    function test_applyERC20() public {
        vm.startPrank(address(this));
        erc20Facet.applyERC20("AKP", "Akpolo Token", 18, 1000);
        vm.stopPrank();

        assertEq(erc20Facet.name(), "Akpolo Token");
        assertEq(erc20Facet.symbol(), "AKP");
        assertEq(erc20Facet.decimals(), 18);
        assertEq(erc20Facet.totalSupply(), 1000);
    }
  

    function testApproveAndTransferFrom() public {
        // First transfer some tokens to user1
        vm.startPrank(address(this));
        erc20Facet.mint(user1, 1000);
        vm.stopPrank();

        // User1 approves User2
        vm.startPrank(user1);
        erc20Facet.approve(user2, 500);
        vm.stopPrank();

        // User2 transfers from User1
        vm.startPrank(user2);
        bool success = erc20Facet.transferFrom(user1, user2, 500);
        vm.stopPrank();

        assertTrue(success);
        assertEq(erc20Facet.balanceOf(user1), 500);
        assertEq(erc20Facet.balanceOf(user2), 500);
        assertEq(erc20Facet.allowance(user1, user2), 0);
    }

    function test_RevertWhen_InsufficientAllowance() public {
        vm.startPrank(address(this));
        erc20Facet.mint(user1, 1000);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("ERC20: insufficient allowance");
        erc20Facet.transferFrom(user1, user2, 500);
        vm.stopPrank();
    }
}