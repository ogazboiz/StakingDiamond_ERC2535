// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC20} from "../interfaces/IERC20.sol";
import {AppStorage} from "../libraries/LibAppStorage.sol";
// string name;
//         string symbol;
//         uint256 totalSupply;
//         uint8 decimals;
//         mapping(address => uint256) balances;
//         mapping(address => mapping(address => uint256)) allowances;

abstract contract ERC20Facet is IERC20 {
    error ERC20Facet__InsufficientBalance();
    error ERC20Facet__InsufficientAllowance();
    
    function applyERC20(string memory _symbol, string memory _name, uint8 _decimals, uint256 _totalSupply) external {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        require(bytes(es.symbol).length == 0, "ERC20Facet: already initialized");
        es.symbol = _symbol;
        es.name = _name;
        es.decimals = _decimals;
        es.totalSupply = _totalSupply;   
    }
    
    function name() external view returns (string memory) {
         AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.name;
    }
    function symbol() external view returns (string memory) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.symbol;
    }
    function decimals() external view returns (uint8) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.decimals;
    }
    function totalSupply() external view returns (uint256) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.balances[account];
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        if (es.balances[msg.sender] < amount) revert ERC20Facet__InsufficientBalance();
        es.balances[msg.sender] -= amount;
        es.balances[to] += amount;
        return true;
    }
    function approve(address spender, uint256 amount) external returns (bool) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        es.allowances[msg.sender][spender] = amount;
        return true;
    }
    function allowance(address owner, address spender) external view returns (uint256) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        return es.allowances[owner][spender];
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        AppStorage.AppStorageStruct storage es = AppStorage.layout();
        if (es.allowances[from][msg.sender] < amount) revert ERC20Facet__InsufficientAllowance();
        if (es.balances[from] < amount) revert ERC20Facet__InsufficientBalance();
        es.allowances[from][msg.sender] -= amount;
        es.balances[from] -= amount;
        es.balances[to] += amount;
        return true;
    }
    
}
