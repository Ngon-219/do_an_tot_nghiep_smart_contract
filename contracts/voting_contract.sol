// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;
import "./factory_contract.sol";

contract VotingContract {
    FactoryContract factory;
    uint256 public eventCount;
    mapping(uint256 => VotingEvent) public votingEvents;

    struct VotingEvent {
        string event_name;
        uint256 created_at;
        address created_by;
        string[] options;
        mapping(string => uint256) scores;
        mapping(address => mapping(string => bool)) hasVoted;
    }

    constructor(address _factory) {
        factory = FactoryContract(_factory);
    }

    function createVotingEvent(string memory _name, string[] memory _options, address _signer) public {
        require(factory.isSigner(_signer), "Signer is not valid");
        require(_options.length > 1, "At least 2 options provide");

        uint256 eventId = eventCount++;
        VotingEvent storage ve = votingEvents[eventId];
        ve.event_name = _name;
        ve.created_at = block.timestamp;
        ve.created_by = msg.sender;

        for (uint i = 0; i < _options.length; i++) {
            ve.options.push(_options[i]);
            ve.scores[_options[i]] = 0;
        }
    }

    function vote(uint256 eventId, string memory option) public {
        require(factory.getUserId(msg.sender) > 0, "Only registered users can vote");
        
        VotingEvent storage ve = votingEvents[eventId];
        require(!ve.hasVoted[msg.sender][option], "You have already voted for this option");
        
        ve.scores[option]++;
        ve.hasVoted[msg.sender][option] = true;
    }

    function getVoteCount(uint256 eventId, string memory option) public view returns (uint256) {
        return votingEvents[eventId].scores[option];
    }
}