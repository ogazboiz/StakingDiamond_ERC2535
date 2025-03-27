//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Facet} from "./ERC20Facet.sol";
import {AppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import{IERC20} from "../interfaces/IERC20.sol";
import{IERC721} from "../interfaces/IERC721.sol";
import{IERC1155} from "../interfaces/IERC1155.sol";
import {IStaking} from "../interfaces/IStaking.sol";
import {IRewardToken} from "../interfaces/IRewardToken.sol";

contract Staking is IStaking {
    function applyStaking(
        uint256 _REWARD_RATE,
        uint256 _DECAY_RATE,
        uint256 _PRECISION
    ) external override {
        LibDiamond.enforceIsContractOwner();
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        es.REWARD_RATE = _REWARD_RATE;
        es.DECAY_RATE = _DECAY_RATE;
        es.PRECISION = _PRECISION;   
    }

    function stake(
        TokenType tokenType,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external override {
        if(tokenAddress == address(0)) revert Staking__ZeroAddress();
        if(!_isContract(tokenAddress)) revert Staking__InvalidTokenAddress();

        AppStorage.AppStorageStruct storage es = AppStorage.layout();

        if (tokenType == TokenType.ERC20) {
            _stakeERC20(tokenAddress, amount);
            es.stakers[msg.sender].balance += amount;
            es.totalERC20Staked += amount;
        } 
        else if (tokenType == TokenType.ERC721) {
            // Check for duplicate NFT stake
            if(es.stakers[msg.sender].erc721Stakes[tokenId]) {
                revert Staking__NFTAlreadyStaked();
            }

            _stakeERC721(tokenAddress, tokenId);
            es.stakers[msg.sender].erc721Stakes[tokenId] = true;
            
            // Only push if it's a new tokenId
            bool exists = false;
            for(uint i = 0; i < es.stakers[msg.sender].erc721TokenIds.length; i++) {
                if(es.stakers[msg.sender].erc721TokenIds[i] == tokenId) {
                    exists = true;
                    break;
                }
            }
            if(!exists) {
                es.stakers[msg.sender].erc721TokenIds.push(tokenId);
            }
            es.totalERC721Staked += 1;
        }
        else if (tokenType == TokenType.ERC1155) {
            if(amount == 0) revert Staking__InvalidAmount();
            
            _stakeERC1155(tokenAddress, tokenId, amount);
            es.stakers[msg.sender].erc1155Stakes[tokenId] += amount;
            
            // Only push if it's a new tokenId
            bool exists = false;
            for(uint i = 0; i < es.stakers[msg.sender].erc1155TokenIds.length; i++) {
                if(es.stakers[msg.sender].erc1155TokenIds[i] == tokenId) {
                    exists = true;
                    break;
                }
            }
            if(!exists) {
                es.stakers[msg.sender].erc1155TokenIds.push(tokenId);
            }
            es.totalERC1155Staked += amount;
        }
        else {
            revert Staking__InvalidTokenType();
        }

        // Initialize staking time if first stake
        if (es.stakers[msg.sender].depositTime == 0) {
            es.stakers[msg.sender].depositTime = block.timestamp;
            es.stakers[msg.sender].lastRewardTime = block.timestamp;
        }
    }

    function _isContract(address addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function _stakeERC20(address tokenAddress, uint256 amount) internal {
        if(amount == 0) revert Staking__InvalidAmount();
        
        IERC20 token = IERC20(tokenAddress);
        if(token.balanceOf(msg.sender) < amount) revert Staking__InsufficientBalance();
        if(token.allowance(msg.sender, address(this)) < amount) revert Staking__InsufficientAllowance();
        
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if(!success) revert Staking__TransferFailed();
    }

    function _stakeERC721(address tokenAddress, uint256 tokenId) internal {
        IERC721 nft = IERC721(tokenAddress);
        if(nft.ownerOf(tokenId) != msg.sender) revert Staking__InsufficientBalance();
        if(!nft.isApprovedForAll(msg.sender, address(this)) && 
           nft.getApproved(tokenId) != address(this)) {
            revert Staking__InsufficientAllowance();
        }
        
        try nft.transferFrom(msg.sender, address(this), tokenId) {
            // Transfer successful
        } catch {
            revert Staking__TransferFailed();
        }
    }

    function _stakeERC1155(address tokenAddress, uint256 tokenId, uint256 amount) internal {
        IERC1155 multiToken = IERC1155(tokenAddress);
        if(multiToken.balanceOf(msg.sender, tokenId) < amount) {
            revert Staking__InsufficientBalance();
        }
        if(!multiToken.isApprovedForAll(msg.sender, address(this))) {
            revert Staking__InsufficientAllowance();
        }
        
        try multiToken.safeTransferFrom(msg.sender, address(this), tokenId, amount, "") {
            // Transfer successful
        } catch {
            revert Staking__TransferFailed();
        }
    }

    function calculateRewards(address staker) public view override returns (uint256) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        
        if (es.stakers[staker].balance == 0) return 0;
        
        uint256 timeStaked = block.timestamp - es.stakers[staker].lastRewardTime;
        
        uint256 baseReward = (es.stakers[staker].balance * es.REWARD_RATE * timeStaked) / (365 days * es.PRECISION);
        
        uint256 bonusReward = _calculateTokenTypeBonus(staker);
        
        uint256 totalReward = baseReward + bonusReward;
        return _applyDecayIfNeeded(staker, totalReward);
    }

    function _calculateTokenTypeBonus(address staker) internal view returns (uint256) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        uint256 bonus = 0;
        
        // Count NFTs (ERC721)
        uint256 nftCount = 0;
        for (uint256 i = 0; i < es.stakers[staker].erc721TokenIds.length; i++) {
            uint256 tokenId = es.stakers[staker].erc721TokenIds[i];
            if (es.stakers[staker].erc721Stakes[tokenId]) {
                nftCount++;
            }
        }
        
        // Calculate NFT bonus (5% APR per NFT)
        if (nftCount > 0) {
            uint256 timeStaked = block.timestamp - es.stakers[staker].lastRewardTime;
            bonus += (es.stakers[staker].balance * 500 * nftCount * timeStaked) / (365 days * es.PRECISION);
        }
        
        // Count ERC1155 tokens
        uint256 erc1155Total = 0;
        for (uint256 i = 0; i < es.stakers[staker].erc1155TokenIds.length; i++) {
            uint256 tokenId = es.stakers[staker].erc1155TokenIds[i];
            erc1155Total += es.stakers[staker].erc1155Stakes[tokenId];
        }

        bonus += (es.stakers[staker].balance * (erc1155Total * 100)) / (365 days * es.PRECISION);
        
        return bonus;
    }

    function _applyDecayIfNeeded(address staker, uint256 reward) internal view returns (uint256) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        
        uint256 stakeDuration = block.timestamp - es.stakers[staker].depositTime;
        
        uint256 decayedReward = reward;
        if (stakeDuration > 30 days) {
            uint256 overTime = stakeDuration - 30 days;
            uint256 decayFactor = (es.DECAY_RATE * overTime) / 30 days;
            
            uint256 maxDecay = reward / 2;
            uint256 decay = (reward * decayFactor) / es.PRECISION;
            decay = decay > maxDecay ? maxDecay : decay;
            
            decayedReward = reward - decay;
        }
        
        return decayedReward;
    }

    function claimRewards(TokenType tokenType, uint256 tokenId) external override {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        
        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "No rewards to claim");
        
        if (tokenType == TokenType.ERC20) {
            es.stakers[msg.sender].balance += rewards;
            es.totalSupply += rewards;
        } 
        else if (tokenType == TokenType.ERC721) {
            require(es.stakers[msg.sender].erc721Stakes[tokenId], "NFT not staked");
            es.stakers[msg.sender].balance += rewards;
            es.totalSupply += rewards;
        }
        else if (tokenType == TokenType.ERC1155) {
            require(es.stakers[msg.sender].erc1155Stakes[tokenId] > 0, "ERC1155 not staked");
            es.stakers[msg.sender].balance += rewards;
            es.totalSupply += rewards;
        }
        
        IRewardToken rewardToken = IRewardToken(es.rewardTokenAddress);
        rewardToken.mint(msg.sender, rewards);
        es.stakers[msg.sender].lastRewardTime = block.timestamp;
    }

    function getStakerInfo(address staker) external view override returns (
        uint256 balance,
        uint256 depositTime,
        uint256 lastRewardTime
    ) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return (
            es.stakers[staker].balance,
            es.stakers[staker].depositTime,
            es.stakers[staker].lastRewardTime
        );
    }

    function getStakerERC721Info(address staker, uint256 tokenId) external view override returns (bool) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.stakers[staker].erc721Stakes[tokenId];
    }
    function getStakerERC1155Info(address staker, uint256 tokenId) external view override returns (uint256) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.stakers[staker].erc1155Stakes[tokenId];
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    
    function setRewardToken(address tokenAddress) external override {
        LibDiamond.enforceIsContractOwner();
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        es.rewardTokenAddress = tokenAddress;
    }
}