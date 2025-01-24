// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { console2 } from "forge-std/console2.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Voting {
    // State variables
    IERC20 public immutable token;
    uint256 public immutable votingDeadline;
    
    // Vote tracking
    uint256 public votesFor;
    uint256 public votesAgainst;
    mapping(address => bool) public hasVoted;
    mapping(address => uint256) public voteWeight;
    mapping(address => bool) public voteDirection; // true = For, false = Against
    
    // Events
    event VoteCasted(address indexed voter, bool vote, uint256 weight);
    event VotesRemoved(address indexed voter, uint256 weight);
    
    constructor(address _tokenAddress, uint256 _votingPeriod) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = IERC20(_tokenAddress);
        votingDeadline = block.timestamp + _votingPeriod;
    }
    
    function vote(bool _voteFor) external {
        require(block.timestamp < votingDeadline, "Voting period has ended");
        require(!hasVoted[msg.sender], "Already voted");
        
        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No voting power");
        
        if (_voteFor) {
            votesFor += balance;
        } else {
            votesAgainst += balance;
        }
        
        hasVoted[msg.sender] = true;
        voteWeight[msg.sender] = balance;
        voteDirection[msg.sender] = _voteFor;
        
        emit VoteCasted(msg.sender, _voteFor, balance);
    }
    
    function removeVotes(address from) external {
        require(msg.sender == address(token), "Only token contract can remove votes");
        
        if (hasVoted[from]) {
            uint256 weight = voteWeight[from];
            bool votedFor = voteDirection[from];
            
            if (votedFor) {
                votesFor -= weight;
            } else {
                votesAgainst -= weight;
            }
            
            hasVoted[from] = false;
            voteWeight[from] = 0;
            
            emit VotesRemoved(from, weight);
        }
    }
    
    function getResult() external view returns (bool) {
        require(block.timestamp >= votingDeadline, "Voting period not over");
        return votesFor > votesAgainst;
    }
}