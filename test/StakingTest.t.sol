// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DiamondUtils} from "./helpers/DiamondUtils.sol";
import {AppStorage} from "../contracts/libraries/LibAppStorage.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IStaking} from "../contracts/interfaces/IStaking.sol";

contract StakingTest is Test, DiamondUtils {
    MockERC20 public token;
    MockERC721 public nft;
    MockERC1155 public multiToken;
    address public user1;
    address public user2;
    IStaking public staking;

    function setUp() public {
        // Deploy diamond with facets
        deployDiamond();
        
        // Initialize staking interface
        staking = IStaking(address(diamond));
        
       
        token = new MockERC20("Akpolo Token", "AKP");
        nft = new MockERC721("Akpolo NFT", "AKPNFT");
        multiToken = new MockERC1155("akpolo-uri/");
        
        // Setup test accounts
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Mint tokens to users
        token.mint(user1, 1000e18);
        nft.mint(user1, 1);
        multiToken.mint(user1, 1, 100, "");
        
        // Setup staking parameters and reward token
        vm.startPrank(diamondOwner);
        staking.applyStaking(1000, 100, 10000); // 10% APR, 1% decay, precision 10000
        staking.setRewardToken(address(token));
        vm.stopPrank();
    }

    // Test ERC20 Staking
    function testStakeERC20() public {
        uint256 amount = 100e18;
        
        vm.startPrank(user1);
        token.approve(address(diamond), amount);
        
        staking.stake(
            IStaking.TokenType.ERC20,
            address(token),
            0,
            amount
        );
        vm.stopPrank();

        (uint256 balance, uint256 depositTime, uint256 lastRewardTime) = staking.getStakerInfo(user1);
        assertEq(balance, amount, "Incorrect staker balance");
    }

    function testStakeERC721() public {
        uint256 tokenId = 1;
        
        vm.startPrank(user1);
        nft.approve(address(diamond), tokenId);
        
        staking.stake(
            IStaking.TokenType.ERC721,
            address(nft),
            tokenId,
            0
        );
        vm.stopPrank();

        
        assertTrue(staking.getStakerERC721Info(user1, tokenId));
        // assertEq(es.totalERC721Staked, 1);
    }

    function testStakeERC1155() public {
        uint256 tokenId = 1;
        uint256 amount = 50;
        
        vm.startPrank(user1);
        multiToken.setApprovalForAll(address(diamond), true);
        
        staking.stake(
            IStaking.TokenType.ERC1155,
            address(multiToken),
            tokenId,
            amount
        );
        vm.stopPrank();

        assertEq(staking.getStakerERC1155Info(user1, tokenId), amount);
        
    }

    // Test Rewards
    function testRewardCalculation() public {
        uint256 amount = 1000e18;
        
        // Stake tokens
        vm.startPrank(user1);
        token.approve(address(diamond), amount);
        staking.stake(IStaking.TokenType.ERC20, address(token), 0, amount);
        
        // Advance time 30 days
        vm.warp(block.timestamp + 30 days);
        
        uint256 expectedReward = (amount * 1000 * 30 days) / (365 days * 10000);
        uint256 actualReward = staking.calculateRewards(user1);
        
        assertApproxEqRel(actualReward, expectedReward, 1e16); // 1% tolerance
        vm.stopPrank();
    }

    function testRewardWithNFTBonus() public {
        uint256 amount = 1000e18;
        uint256 tokenId = 1;
        
        vm.startPrank(user1);
        // Stake ERC20
        token.approve(address(diamond), amount);
        staking.stake(IStaking.TokenType.ERC20, address(token), 0, amount);
        
        // Stake NFT
        nft.approve(address(diamond), tokenId);
        staking.stake(IStaking.TokenType.ERC721, address(nft), tokenId, 0);
        
        // Advance time 30 days
        vm.warp(block.timestamp + 30 days);
        
        uint256 baseReward = (amount * 1000 * 30 days) / (365 days * 10000);
        uint256 nftBonus = (amount * 500 * 30 days) / (365 days * 10000); // 5% bonus
        uint256 expectedTotal = baseReward + nftBonus;
        
        uint256 actualReward = staking.calculateRewards(user1);
        assertApproxEqRel(actualReward, expectedTotal, 1e16);
        vm.stopPrank();
    }

    // Test Claim Rewards
    function testClaimRewards() public {
        uint256 amount = 1000e18;
        
        vm.startPrank(user1);
        token.approve(address(diamond), amount);
        staking.stake(IStaking.TokenType.ERC20, address(token), 0, amount);
        
        vm.warp(block.timestamp + 30 days);
        
        uint256 rewardsBefore = staking.calculateRewards(user1);
        staking.claimRewards(IStaking.TokenType.ERC20, 0);
        
        (uint256 balance,,) = staking.getStakerInfo(user1);
        assertEq(balance, amount + rewardsBefore, "Incorrect balance after claim");
        vm.stopPrank();
    }

    // Test Decay
    function testRewardDecay() public {
        uint256 amount = 1000e18;
        
        vm.startPrank(user1);
        token.approve(address(diamond), amount);
        staking.stake(IStaking.TokenType.ERC20, address(token), 0, amount);
        
        // Advance time 60 days (30 days beyond decay start)
        vm.warp(block.timestamp + 60 days);
        
        uint256 baseReward = (amount * 1000 * 60 days) / (365 days * 10000);
        uint256 decayAmount = (baseReward * 100 * 30 days) / (30 days * 10000);
        uint256 expectedReward = baseReward - decayAmount;
        
        uint256 actualReward = staking.calculateRewards(user1);
        assertApproxEqRel(actualReward, expectedReward, 1e16);
        vm.stopPrank();
    }

    // Test Revert Cases
    function testRevert_InvalidAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(IStaking.Staking__InvalidAmount.selector);
        staking.stake(IStaking.TokenType.ERC20, address(token), 0, 0);
        vm.stopPrank();
    }

    function testRevert_InsufficientBalance() public {
        vm.startPrank(user1);
        token.approve(address(diamond), type(uint256).max);
        vm.expectRevert(IStaking.Staking__InsufficientBalance.selector);
        staking.stake(IStaking.TokenType.ERC20, address(token), 0, 2000e18);
        vm.stopPrank();
    }

    function testGetStakerInfo() public {
        uint256 amount = 100e18;
        
        vm.startPrank(user1);
        token.approve(address(diamond), amount);
        staking.stake(IStaking.TokenType.ERC20, address(token), 0, amount);
        
        (uint256 balance, uint256 depositTime, uint256 lastRewardTime) = staking.getStakerInfo(user1);
        
        assertEq(balance, amount, "Incorrect balance");
        assertEq(depositTime, block.timestamp, "Incorrect deposit time");
        assertEq(lastRewardTime, block.timestamp, "Incorrect last reward time");
        vm.stopPrank();
    }
} 