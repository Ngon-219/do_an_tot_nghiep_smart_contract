// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;
import "./indentity.sol";

contract StudentScore {
    IdentityContract identity;

    constructor(address _identity) {
        identity = IdentityContract(_identity);
    }

    mapping(uint256 => uint256) public scores;

    function setScore(uint256 score) external {
        uint256 userId = identity.getUserId(msg.sender);
        require(userId > 0, "User not registered");
        scores[userId] = score;
    }

    function minorScore(uint256 userId, uint256 decrement) external {
        require(scores[userId] >= decrement, "Score cannot be negative");
        require(identity.getUserId(msg.sender) > 0, "Only registered users can minor score");
        scores[userId] -= decrement;
    }

    function addScore(uint256 userId, uint256 increment) external {
        require(identity.getUserId(msg.sender) > 0, "Only registered users can add score");
        scores[userId] += increment;
    }

    function getScore(uint256 userId) external view returns (uint256) {
        require(identity.getUserId(msg.sender) > 0, "Only registered users can view score");
        return scores[userId];
    }
}