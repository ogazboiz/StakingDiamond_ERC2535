//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Facet} from "./ERC20Facet.sol";
import {AppStorage} from "../libraries/LibAppStorage.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Staking {
    error Staking__InsufficientBalance();
    error Staking__InvalidAmount();
    error Staking__InsufficientAllowance();


    mapping(address => Staker) public stakers;

    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct StakeInfo {
        TokenType tokenType;
        address tokenAddress;
        uint256 tokenId;     // Used for ERC721 and ERC1155
        uint256 amount;      // Used for ERC20 and ERC1155
    }

function applyStaking(  uint _REWARD_RATE, uint _DECAY_RATE, uint _STAKING_DURATION, uint _PRECISION) external {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        es.REWARD_RATE = _REWARD_RATE;
        es.DECAY_RATE = _DECAY_RATE;
        es.STAKING_DURATION = _STAKING_DURATION;
        es.PRECISION = _PRECISION;   
    }
    function stake(StakeInfo calldata stakeInfo) external {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        
        if (stakeInfo.tokenType == TokenType.ERC20) {
            _stakeERC20(stakeInfo.tokenAddress, stakeInfo.amount);
        } 
        else if (stakeInfo.tokenType == TokenType.ERC721) {
            _stakeERC721(stakeInfo.tokenAddress, stakeInfo.tokenId);
        }
        else if (stakeInfo.tokenType == TokenType.ERC1155) {
            _stakeERC1155(stakeInfo.tokenAddress, stakeInfo.tokenId, stakeInfo.amount);
        }

        // Update staker info
        if (es.stakers[msg.sender].balance == 0) {
            es.stakers[msg.sender].depositTime = block.timestamp;
            es.stakers[msg.sender].lastRewardTime = block.timestamp;
        }
        es.stakers[msg.sender].balance += stakeInfo.amount;
        es.stakers[msg.sender].erc721Stakes[stakeInfo.tokenId] = true;
        es.stakers[msg.sender].erc1155Stakes[stakeInfo.tokenId] += stakeInfo.amount;
        es.totalStaked += stakeInfo.amount;

    }

    function _stakeERC20(address tokenAddress, uint256 amount) internal {
        IERC20 Tk = IERC20(tokenAddress);
           if (amount == 0) revert Staking__InvalidAmount();
        if (Tk.balanceOf(msg.sender) < amount) revert Staking__InsufficientBalance();
        if (Tk.allowance(msg.sender, address(this)) < amount) revert Staking__InsufficientAllowance();
        Tk.transferFrom(msg.sender, address(this), amount)

        
    
        
    }

    function _stakeERC721(address tokenAddress, uint256 tokenId) internal {
        IERC721 nft = IERC721(tokenAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(nft.isApprovedForAll(msg.sender, address(this)) || 
                nft.getApproved(tokenId) == address(this), "Not approved");
        
        nft.transferFrom(msg.sender, address(this), tokenId);
    }

    function _stakeERC1155(address tokenAddress, uint256 tokenId, uint256 amount) internal {
        IERC1155 multiToken = IERC1155(tokenAddress);
        require(multiToken.balanceOf(msg.sender, tokenId) >= amount, "Insufficient balance");
        require(multiToken.isApprovedForAll(msg.sender, address(this)), "Not approved");
        
        multiToken.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
    }
}

