//SPDX-License-Identifier: MIT

pragma solidity 0.8.26;
import {console2} from "forge-std/console2.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract EthStreaming is Ownable(msg.sender) {
    uint public immutable unlockTime;
    
    struct Stream {
        uint cap;
        uint timeOfLastWithdrawal;
    }
    
    mapping(address => Stream) public streams;
    
    event AddStream(address recipient, uint cap);
    event Withdraw(address recipient, uint amount);
    
    constructor(uint _unlockTime) {
        unlockTime = _unlockTime;
    }
    
    receive() external payable {}
    
    function addStream(address recipient, uint cap) external onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        streams[recipient] = Stream(cap, block.timestamp - unlockTime);
        emit AddStream(recipient, cap);
    }
    
    function withdraw(uint amount) external {
        Stream storage stream = streams[msg.sender];
        require(stream.cap > 0, "No stream exists for caller");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        uint timeSinceLastWithdraw = block.timestamp - stream.timeOfLastWithdrawal;
        uint unlockedAmount = (stream.cap * timeSinceLastWithdraw) / unlockTime;
        
        if (unlockedAmount > stream.cap) {
            unlockedAmount = stream.cap;
        }
        
        require(amount <= unlockedAmount, "Amount exceeds unlocked balance");
        
        if (amount == unlockedAmount) {
            stream.timeOfLastWithdrawal = block.timestamp;
        }
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, amount);
    }
}