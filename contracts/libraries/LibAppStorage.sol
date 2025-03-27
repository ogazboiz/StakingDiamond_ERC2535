// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

library AppStorage {
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct StakeInfo {
        TokenType tokenType;
        address tokenAddress;
        uint256 tokenId; // Used for ERC721 and ERC1155
        uint256 amount; // Used for ERC20 and ERC1155
    }

    struct Staker {
        uint256 balance; // Tracks user's staked balance
        uint256 depositTime;
        uint256 lastRewardTime;
        uint256 pendingRewards;
        mapping(uint256 => bool) erc721Stakes;
        mapping(uint256 => uint256) erc1155Stakes;
        uint256[] erc721TokenIds;
        uint256[] erc1155TokenIds;
    }

    struct AppStorageStruct {
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        mapping(address => Staker) stakers;
        mapping(address => uint256) stakedERC20s;
        mapping(address => mapping(uint256 => address)) stakedERC721s;
        uint256 totalERC20Staked;
        uint256 totalERC721Staked;
        uint256 totalERC1155Staked;
        uint256 minStakeDuration;
        uint256 maxStakeDuration;
        uint256 earlyUnstakePenalty;
        uint256 REWARD_RATE;
        uint256 DECAY_RATE;
        uint256 PRECISION;
        address rewardTokenAddress;
        mapping(address => uint256) rewardBalances;
    }

    function layout() internal pure returns (AppStorageStruct storage es) {
        assembly {
            es.slot := 0
        }
    }
}
