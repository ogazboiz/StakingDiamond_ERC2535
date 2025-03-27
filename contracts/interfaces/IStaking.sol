// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    error Staking__InvalidAmount();
    error Staking__InsufficientBalance();
    error Staking__InsufficientAllowance();
    error Staking__NFTAlreadyStaked();
    error Staking__InvalidTokenAddress();
    error Staking__InvalidTokenType();
    error Staking__TransferFailed();
    error Staking__ZeroAddress();

    function applyStaking(
        uint256 _REWARD_RATE,
        uint256 _DECAY_RATE,
        uint256 _PRECISION
    ) external;

    function stake(
        TokenType tokenType,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external;

    function calculateRewards(address staker) external view returns (uint256);
    
    function claimRewards(TokenType tokenType, uint256 tokenId) external;

    function getStakerERC721Info(address staker, uint256 tokenId) external view returns (bool);
    function getStakerERC1155Info(address staker, uint256 tokenId) external view returns (uint256);
    function getStakerInfo(address staker) external view returns (
        uint256 balance,
        uint256 depositTime,
        uint256 lastRewardTime
    );
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);


    function setRewardToken(address tokenAddress) external;

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

    struct StakerInfo {
        uint256 balance;
        uint256 depositTime;
        uint256 lastRewardTime;
        mapping(uint256 => bool) erc721Stakes;
        mapping(uint256 => uint256) erc1155Stakes;
        uint256[] erc721TokenIds;
        uint256[] erc1155TokenIds;
    }
} 