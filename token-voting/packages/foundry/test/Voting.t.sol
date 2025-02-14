// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../contracts/DecentralizedResistanceToken.sol";
import "../contracts/Voting.sol";

contract VotingTest is Test {
    DecentralizedResistanceToken public token;
    Voting public voting;
    address public userOne = address(0x123);
    address public userTwo = address(0x456);
    address public userThree = address(0x782);

    function setUp() public {
        token = new DecentralizedResistanceToken(1000000 * 10 ** 18); // 1,000,000 tokens
        // Use a different contract than default if CONTRACT_PATH env var is set
        string memory contractPath = vm.envOr("CONTRACT_PATH", string("none"));
        if (keccak256(abi.encodePacked(contractPath)) != keccak256(abi.encodePacked("none"))) {
            bytes memory args = abi.encode(address(token), 86400);
            bytes memory bytecode = abi.encodePacked(vm.getCode(contractPath), args);
            address payable deployed;
            assembly {
                deployed := create(0, add(bytecode, 0x20), mload(bytecode))
            }
            voting = Voting(deployed);
        } else {
            voting = new Voting(address(token), 86400); // 1 day voting period
        }
        token.setVotingContract(address(voting)); // SetVotingContract
        // Distribute tokens
        token.transfer(userOne, 1000 * 10 ** 18); // 1000 tokens to userOne
        token.transfer(userTwo, 2000 * 10 ** 18); // 2000 tokens to userTwo
        token.transfer(userThree, 1000 * 10 ** 18); // 1000 tokens to userTwo
    }

    function testVotingFor() public {
        vm.prank(userOne);
        voting.vote(true);

        assertEq(voting.votesFor(), token.balanceOf(userOne));
        assertEq(voting.votesAgainst(), 0);
        assertTrue(voting.hasVoted(userOne));
    }

    function testVotingAgainst() public {
        vm.prank(userTwo);
        voting.vote(false);

        assertEq(voting.votesFor(), 0);
        assertEq(voting.votesAgainst(), token.balanceOf(userTwo));
        assertTrue(voting.hasVoted(userTwo));
    }

    function testDoubleVoting() public {
        //User can't double voting
        vm.startPrank(userOne);
        voting.vote(true);
        vm.expectRevert();
        voting.vote(true);
        vm.stopPrank();

        assertEq(voting.votesFor(), token.balanceOf(userOne));
        assertTrue(voting.hasVoted(userOne));
    }

    function testNoTokensToVote() public {
        // 0 in the balanceof userThree, so he can't vote
        address userFour = address(0x789);
        vm.prank(userFour);
        vm.expectRevert();
        voting.vote(true);

        assertFalse(voting.hasVoted(userFour));
    }

    function testTieVotingResult() public {
        // A tie should result in rejection
        vm.prank(userOne);
        voting.vote(true);
        vm.prank(userThree);
        voting.vote(false);
        vm.warp(block.timestamp + 86400 + 1);
        bool result = voting.getResult();
        uint votesFor = voting.votesFor();
        uint votesAgainst = voting.votesAgainst();

        assertEq(result, false);
        assertEq(votesFor, 1000 * 10 ** 18);
        assertEq(votesAgainst, 1000 * 10 ** 18);
    }

    function testVotingResultRejected() public {
        // 1000 for vs 2000 against
        vm.prank(userOne);
        voting.vote(true);
        vm.prank(userTwo);
        voting.vote(false);
        vm.warp(block.timestamp + 86400 + 1);
        bool result = voting.getResult();
        uint votesFor = voting.votesFor();
        uint votesAgainst = voting.votesAgainst();

        assertEq(result, false);
        assertEq(votesFor, 1000 * 10 ** 18);
        assertEq(votesAgainst, 2000 * 10 ** 18);
    }

    function testVotingResultApproved() public {
        // 2000 for vs 1000 against
        vm.prank(userOne);
        voting.vote(false);
        vm.prank(userTwo);
        voting.vote(true);
        vm.warp(block.timestamp + 86400 + 1);
        bool result = voting.getResult();

        assertEq(result, true);
    }
    function testGetResultBeforeDeadline() public {
        // Try to get the result before the voting deadline
        vm.prank(userOne);
        voting.vote(true);
        vm.prank(userTwo);
        voting.vote(false);
        vm.expectRevert();
        voting.getResult();
    }
    function testVoteAfterDeadline() public {
        // Try to vote after the voting deadline
        vm.warp(block.timestamp + 86400 + 1);
        vm.prank(userOne);
        vm.expectRevert();
        voting.vote(true);
    }
    function testVoteRemovalOnTransfer() public {
        // User votes are removed when transfer any quantity of tokens
        vm.startPrank(userOne);
        voting.vote(true);
        assertEq(voting.votesFor(), token.balanceOf(userOne)); 
        token.transfer(userTwo, 500 * 10 ** 18);
        vm.stopPrank();

        assertEq(voting.votesFor(), 0); 
        assertFalse(voting.hasVoted(userOne)); 
        assertEq(token.balanceOf(userOne), 500 * 10 ** 18);
        assertEq(token.balanceOf(userTwo), 2500 * 10 ** 18);
    }

     function testNotVotingCotractAddressCantCallRemoval() public {
        // Only the token contract can call the removal
        vm.prank(userOne);
        voting.vote(true);
        vm.prank(userTwo);
        voting.vote(false);
        vm.expectRevert();
        voting.removeVotes(userOne);

        assertTrue(voting.hasVoted(userOne)); 
        assertTrue(voting.hasVoted(userTwo)); 
        assertEq(token.balanceOf(userOne), voting.votesFor());
        assertEq(token.balanceOf(userTwo), voting.votesAgainst());
    }

}