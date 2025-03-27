// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

library LibAppStorage {
    struct AppStorageStruct {
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => mapping(address => uint256)) allowances;
        mapping(address => Staker) stakers;
        mapping(address => uint256) stakedERC20s;
        mapping(address => mapping(uint256 => address)) stakedERC721s;
        uint256 totalStaked;
        uint256 minStakeDuration;
        uint256 maxStakeDuration;
        uint256 earlyUnstakePenalty;
           uint public REWARD_RATE;
    uint public DECAY_RATE;
    uint public STAKING_DURATION;
    uint public PRECISION ;
 

    }
    struct Staker {
        uint256 balance;
        uint256 rewards;
        uint256 depositTime;
        uint256 lastRewardTime;
        uint256 rewardPerTokenPaid;
        mapping(uint256 => bool) erc721Stakes;
  mapping(uint256 => uint256) erc1155Stakes;
    }

    function layout() internal pure returns (AppStorageStruct storage l) {
        assembly {
            l.slot := 0
        }
    }
}
