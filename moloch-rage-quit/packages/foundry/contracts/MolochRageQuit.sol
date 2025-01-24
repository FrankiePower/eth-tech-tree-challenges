//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import { console2 } from "forge-std/console2.sol";

contract MolochRageQuit {
    struct Proposal {
        address proposer;
        address contractAddr;
        bytes data;
        uint256 votes;
        uint256 deadline;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public proposalCount;

    event ProposalCreated(uint proposalId, address proposer, address contractToCall, bytes dataToCallWith, uint deadline);
    event MemberAdded(address newMember);
    event Voted(uint proposalId, address member);
    event ProposalExecuted(uint proposalId);
    event RageQuit(address member, uint returnedETH);

    constructor(uint256 initialShares) {
        require(initialShares > 0, "Initial shares must be greater than 0");
        shares[msg.sender] = initialShares;
        totalShares = initialShares;
    }

    modifier onlyMember() {
        require(shares[msg.sender] > 0, "Not a member");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Only callable through proposal execution");
        _;
    }

    function propose(
        address contractToCall,
        bytes calldata data,
        uint deadline
    ) external onlyMember returns (uint256) {
        require(contractToCall != address(0), "Invalid contract address");
        require(deadline > block.timestamp, "Deadline must be in the future");

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.proposer = msg.sender;
        newProposal.contractAddr = contractToCall;
        newProposal.data = data;
        newProposal.deadline = deadline;

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            contractToCall,
            data,
            deadline
        );

        return proposalCount;
    }

    function addMember(address newMember, uint256 newShares) external onlySelf {
        require(newMember != address(0), "Invalid member address");
        require(newShares > 0, "Shares must be greater than 0");
        require(shares[newMember] == 0, "Already a member");

        shares[newMember] = newShares;
        totalShares += newShares;

        emit MemberAdded(newMember);
    }

    function vote(uint256 proposalId) external onlyMember {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(block.timestamp < proposal.deadline, "Voting period ended");

        proposal.votes += shares[msg.sender];
        proposal.hasVoted[msg.sender] = true;

        emit Voted(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        require(block.timestamp >= proposal.deadline, "Voting period not ended");
        require(proposal.votes > totalShares / 2, "Proposal did not pass");

        (bool success,) = proposal.contractAddr.call(proposal.data);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(proposalId);
    }

    function rageQuit() external onlyMember {
        uint256 memberShares = shares[msg.sender];
        require(memberShares > 0, "No shares to quit with");

        uint256 ethShare = (address(this).balance * memberShares) / totalShares;
        totalShares -= memberShares;
        shares[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: ethShare}("");
        require(success, "ETH transfer failed");

        emit RageQuit(msg.sender, ethShare);
    }

    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        address contractAddr,
        bytes memory data,
        uint256 votes,
        uint256 deadline
    ) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.contractAddr,
            proposal.data,
            proposal.votes,
            proposal.deadline
        );
    }

    function isMember(address account) external view returns (bool) {
        return shares[account] > 0;
    }

    receive() external payable {}
}
