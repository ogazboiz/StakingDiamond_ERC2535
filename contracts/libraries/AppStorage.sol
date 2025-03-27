// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AppStorage {
    struct AppStorageStruct {
        // ... existing storage variables ...
        
        // ERC20 storage
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
    }

    function layout() internal pure returns (AppStorageStruct storage s) {
        assembly {
            s.slot := 0
        }
    }
} 