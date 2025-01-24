//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/console2.sol";

import "../contracts/MockToken.sol";

contract Multisend {
    
    event SuccessfulETHTransfer(
        address _sender,
        address payable[] _recipients,
        uint256[] _amounts
    );

    event SuccessfulTokenTransfer(
        address indexed _sender,
        address[] indexed _recipients,
        uint256[] _amounts,
        address _token
    );

    function sendETH(
        address payable[] memory _recipients,
        uint256[] memory _amounts
    ) public payable {
        require(
            _recipients.length == _amounts.length,
            "No of recipients and amounts must be equal"
        );

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        require(msg.value == totalAmount, "Incorrect ETH amount sent");

        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "Invalid recipient address");
            (bool success, ) = _recipients[i].call{value: _amounts[i]}("");
            require(success, "ETH transfer failed");
        }

        emit SuccessfulETHTransfer(msg.sender, _recipients, _amounts);
    }

    function sendTokens(
        address[] memory _recipients,
        uint256[] memory _amounts,
        address _token
    ) public {
        require(
            _recipients.length == _amounts.length,
            "No of recipients and amounts must be equal"
        );
        require(_token != address(0), "Invalid token address");

        IERC20 token = IERC20(_token);

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        require(
            token.allowance(msg.sender, address(this)) >= totalAmount,
            "Insufficient allowance"
        );

        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "Invalid recipient address");
            require(
                token.transferFrom(msg.sender, _recipients[i], _amounts[i]),
                "Token transfer failed"
            );
        }

        emit SuccessfulTokenTransfer(msg.sender, _recipients, _amounts, _token);
    }
}