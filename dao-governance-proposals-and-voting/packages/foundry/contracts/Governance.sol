// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Governance {
    // State variables
    IERC20 public immutable token;
    uint256 public immutable votingPeriod;
    
    struct Proposal {
        string title;
        uint256 deadline;
        address creator;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) voteDirection;
        mapping(address => uint256) voteWeight;
    }
    
    // Proposal storage
    uint256 public proposalCount;
    uint256 public activeProposalId;
    uint256 public queuedProposalId;
    mapping(uint256 => Proposal) public proposals;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, string title, uint256 votingDeadline, address creator);
    event VoteCasted(uint256 indexed proposalId, address indexed voter, uint8 vote, uint256 weight);
    event VotesRemoved(address indexed voter, uint8 vote, uint256 weight);
    
    constructor(address _tokenAddress, uint256 _votingPeriod) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_votingPeriod > 0, "Invalid voting period");
        token = IERC20(_tokenAddress);
        votingPeriod = _votingPeriod;
    }
    
    function propose(string memory title) external returns (uint256) {
        require(bytes(title).length > 0, "Empty title");
        require(token.balanceOf(msg.sender) > 0, "No voting power");
        
        // Check and update active proposal if needed
        if (activeProposalId != 0 && block.timestamp >= proposals[activeProposalId].deadline) {
            if (queuedProposalId != 0) {
                activeProposalId = queuedProposalId;
                queuedProposalId = 0;
            } else {
                activeProposalId = 0;
            }
        }
        
        require(queuedProposalId == 0, "Proposal already queued");
        
        proposalCount++;
        uint256 newProposalId = proposalCount;
        
        Proposal storage newProposal = proposals[newProposalId];
        newProposal.title = title;
        newProposal.creator = msg.sender;
        
        if (activeProposalId == 0) {
            activeProposalId = newProposalId;
            newProposal.deadline = block.timestamp + votingPeriod;
        } else {
            queuedProposalId = newProposalId;
            newProposal.deadline = proposals[activeProposalId].deadline + votingPeriod;
        }
        
        emit ProposalCreated(proposalCount, title, 0, msg.sender);
        return proposalCount;
    }
    
    function getProposal(uint256 id) public view returns (string memory title, uint256 deadline, address creator) {
        require(id > 0 && id <= proposalCount, "Invalid proposal id");
        Proposal storage proposal = proposals[id];
        return (proposal.title, proposal.deadline, proposal.creator);
    }
    
    function vote(uint8 voteType) external {
        require(activeProposalId != 0, "No active proposal");
        require(voteType <= 2, "Invalid vote type");
        
        // Check if active proposal needs to be updated
        if (block.timestamp >= proposals[activeProposalId].deadline) {
            if (queuedProposalId != 0) {
                activeProposalId = queuedProposalId;
                queuedProposalId = 0;
            } else {
                activeProposalId = 0;
                revert("No active proposal");
            }
        }
        
        Proposal storage proposal = proposals[activeProposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        uint256 weight = token.balanceOf(msg.sender);
        require(weight > 0, "No voting power");
        
        if (voteType == 0) {
            proposal.votesAgainst += weight;
        } else if (voteType == 1) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAbstain += weight;
        }
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteDirection[msg.sender] = voteType;
        proposal.voteWeight[msg.sender] = weight;
        
        emit VoteCasted(activeProposalId, msg.sender, voteType, weight);
    }
    
    function removeVotes(address from) external {
        require(msg.sender == address(token), "Only token contract");
        require(activeProposalId != 0, "No active proposal");
        
        Proposal storage proposal = proposals[activeProposalId];
        if (proposal.hasVoted[from]) {
            uint8 voteType = proposal.voteDirection[from];
            uint256 weight = proposal.voteWeight[from];
            
            if (voteType == 0) {
                proposal.votesAgainst -= weight;
            } else if (voteType == 1) {
                proposal.votesFor -= weight;
            } else {
                proposal.votesAbstain -= weight;
            }
            
            proposal.hasVoted[from] = false;
            proposal.voteWeight[from] = 0;
            
            emit VotesRemoved(from, voteType, weight);
        }
    }
    
    function getResult(uint256 proposalId) external view returns (bool) {
        //require(proposalId > 0 && id <= proposalCount, "Invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.deadline, "Voting period not over");
        return proposal.votesFor > proposal.votesAgainst;
    }
}