// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;
import "./factory_contract.sol";

contract StudentScore {
    FactoryContract factory;

    constructor(address _factory) {
        factory = FactoryContract(_factory);
    }

    mapping(uint256 => uint256) public scores;

    function setScore(uint256 score) external {
        uint256 userId = factory.getUserId(msg.sender);
        require(userId > 0, "User not registered");
        scores[userId] = score;
    }

    function minorScore(uint256 userId, uint256 decrement) external {
        require(factory.getUserId(msg.sender) > 0, "Only registered users can minor score");

        if (scores[userId] < decrement) {
            scores[userId] = 0;
        } else {
            scores[userId] -= decrement;
        }
    }

    function addScore(uint256 userId, uint256 increment) external {
        require(factory.getUserId(msg.sender) > 0, "Only registered users can add score");
        scores[userId] += increment;
        if (scores[userId] > 100) {
            scores[userId] = 0;
        }
    }

    function getScore(uint256 userId) external view returns (uint256) {
        require(factory.getUserId(msg.sender) > 0, "Only registered users can view score");
        return scores[userId];
    }
}