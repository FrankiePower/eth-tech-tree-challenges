// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console2} from "forge-std/console2.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract RebasingERC20 is Ownable(msg.sender
) {
    string public constant name = "Rebasing Token";
    string public constant symbol = "$RBT";
    uint8 public constant decimals = 18;

    // Initial total supply set in constructor
    uint256 private _initialSupply;
    
    // Keep track of total supply as it changes with rebases
    uint256 private _totalSupply;
    
    // Scaling factor used to adjust balances after rebases
    uint256 private _scalingFactor = 1e18;  // Start with 1:1 ratio
    
    // Internal balances store the original token amount
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 totalSupply);

    constructor(uint256 initialSupply) {
        _initialSupply = initialSupply;
        _totalSupply = initialSupply;
        _balances[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return (_balances[account] * _scalingFactor) / 1e18;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        address owner = msg.sender;
        
        // Convert amount to internal balance
        uint256 internalAmount = (amount * 1e18) / _scalingFactor;
        require(_balances[owner] >= internalAmount, "ERC20: transfer amount exceeds balance");
        
        unchecked {
            _balances[owner] -= internalAmount;
            _balances[to] += internalAmount;
        }

        emit Transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        address owner = msg.sender;
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        address spender = msg.sender;
        require(_allowances[from][spender] >= amount, "ERC20: insufficient allowance");
        
        // Convert amount to internal balance
        uint256 internalAmount = (amount * 1e18) / _scalingFactor;
        require(_balances[from] >= internalAmount, "ERC20: transfer amount exceeds balance");
        
        unchecked {
            _allowances[from][spender] -= amount;
            _balances[from] -= internalAmount;
            _balances[to] += internalAmount;
        }

        emit Transfer(from, to, amount);
        return true;
    }

    function rebase(int256 rebaseAmount) external onlyOwner {
        require(rebaseAmount != 0, "Invalid rebase amount");
        
        uint256 oldTotalSupply = _totalSupply;
        
        if (rebaseAmount > 0) {
            _totalSupply += uint256(rebaseAmount);
        } else {
            _totalSupply -= uint256(-rebaseAmount);
        }
        
        // Update scaling factor based on supply change
        _scalingFactor = (_scalingFactor * _totalSupply) / oldTotalSupply;
        
        emit Rebase(_totalSupply);
    }
}
