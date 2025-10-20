// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./DataStorage.sol";

contract VotingContract {
    DataStorage public dataStorage;
    uint256 public eventCount;

    struct VotingEvent {
        string eventName;
        string description;
        uint256 createdAt;
        uint256 endTime;
        address createdBy;
        string[] options;
        bool isActive;
        uint256 totalVotes;
    }

    mapping(uint256 => VotingEvent) public votingEvents;
    
    mapping(uint256 => mapping(string => uint256)) public voteScores;
    
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    mapping(uint256 => mapping(address => string)) public userVoteChoice;

    event VotingEventCreated(
        uint256 indexed eventId,
        string eventName,
        address indexed creator,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed eventId,
        address indexed voter,
        string option
    );
    event VotingEventClosed(uint256 indexed eventId, address indexed closedBy);

    constructor(address _dataStorage) {
        require(_dataStorage != address(0), "Invalid DataStorage address");
        dataStorage = DataStorage(_dataStorage);
    }

    modifier onlyAdmin() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        require(
            role == DataStorage.Role.ADMIN || msg.sender == dataStorage.owner(),
            "Only admin can call this"
        );
        _;
    }

    modifier onlyManagerOrTeacher() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        require(
            role == DataStorage.Role.MANAGER || 
            role == DataStorage.Role.TEACHER ||
            role == DataStorage.Role.ADMIN ||
            msg.sender == dataStorage.owner(),
            "Only manager, teacher, or admin can call this"
        );
        _;
    }

    modifier onlyActiveStudent() {
        require(
            dataStorage.isActiveStudent(msg.sender),
            "Only active students can vote"
        );
        _;
    }

    function createVotingEvent(
        string memory _name,
        string memory _description,
        string[] memory _options,
        uint256 _durationInDays
    ) external onlyManagerOrTeacher returns (uint256) {
        require(bytes(_name).length > 0, "Event name required");
        require(_options.length >= 2, "At least 2 options required");
        require(_durationInDays > 0 && _durationInDays <= 365, "Invalid duration");

        uint256 eventId = eventCount++;
        uint256 endTime = block.timestamp + (_durationInDays * 1 days);

        votingEvents[eventId] = VotingEvent({
            eventName: _name,
            description: _description,
            createdAt: block.timestamp,
            endTime: endTime,
            createdBy: msg.sender,
            options: _options,
            isActive: true,
            totalVotes: 0
        });

        for (uint256 i = 0; i < _options.length; i++) {
            voteScores[eventId][_options[i]] = 0;
        }

        emit VotingEventCreated(eventId, _name, msg.sender, endTime);
        return eventId;
    }

    function closeVotingEvent(uint256 _eventId) external {
        VotingEvent storage ve = votingEvents[_eventId];
        require(ve.createdAt > 0, "Event not found");
        require(ve.isActive, "Event already closed");
        
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        require(
            msg.sender == ve.createdBy || 
            role == DataStorage.Role.MANAGER ||
            role == DataStorage.Role.TEACHER ||
            role == DataStorage.Role.ADMIN ||
            msg.sender == dataStorage.owner(),
            "Only creator, manager, teacher, or admin can close event"
        );

        ve.isActive = false;
        emit VotingEventClosed(_eventId, msg.sender);
    }

    function vote(uint256 _eventId, string memory _option) external onlyActiveStudent {
        VotingEvent storage ve = votingEvents[_eventId];
        
        require(ve.createdAt > 0, "Event not found");
        require(ve.isActive, "Voting event is closed");
        require(block.timestamp < ve.endTime, "Voting period has ended");
        require(!hasVoted[_eventId][msg.sender], "You have already voted in this event");
        
        bool optionExists = false;
        for (uint256 i = 0; i < ve.options.length; i++) {
            if (keccak256(bytes(ve.options[i])) == keccak256(bytes(_option))) {
                optionExists = true;
                break;
            }
        }
        require(optionExists, "Invalid option");

        hasVoted[_eventId][msg.sender] = true;
        userVoteChoice[_eventId][msg.sender] = _option;
        voteScores[_eventId][_option]++;
        ve.totalVotes++;

        emit VoteCast(_eventId, msg.sender, _option);
    }

    function getVoteCount(uint256 _eventId, string memory _option) external view returns (uint256) {
        return voteScores[_eventId][_option];
    }

    function getEventOptions(uint256 _eventId) external view returns (string[] memory) {
        return votingEvents[_eventId].options;
    }

    function getEventInfo(uint256 _eventId) external view returns (
        string memory eventName,
        string memory description,
        uint256 createdAt,
        uint256 endTime,
        address createdBy,
        bool isActive,
        uint256 totalVotes
    ) {
        VotingEvent storage ve = votingEvents[_eventId];
        require(ve.createdAt > 0, "Event not found");
        
        return (
            ve.eventName,
            ve.description,
            ve.createdAt,
            ve.endTime,
            ve.createdBy,
            ve.isActive,
            ve.totalVotes
        );
    }

    function hasUserVoted(uint256 _eventId, address _user) external view returns (bool) {
        return hasVoted[_eventId][_user];
    }

    function getUserVote(uint256 _eventId, address _user) external view returns (string memory) {
        require(hasVoted[_eventId][_user], "User has not voted");
        return userVoteChoice[_eventId][_user];
    }

    function getVotingResults(uint256 _eventId) external view returns (
        string[] memory options,
        uint256[] memory votes
    ) {
        VotingEvent storage ve = votingEvents[_eventId];
        require(ve.createdAt > 0, "Event not found");
        
        uint256 optionCount = ve.options.length;
        string[] memory eventOptions = new string[](optionCount);
        uint256[] memory voteCounts = new uint256[](optionCount);
        
        for (uint256 i = 0; i < optionCount; i++) {
            eventOptions[i] = ve.options[i];
            voteCounts[i] = voteScores[_eventId][ve.options[i]];
        }
        
        return (eventOptions, voteCounts);
    }

    function getTotalEvents() external view returns (uint256) {
        return eventCount;
    }

    function updateDataStorage(address _newDataStorage) external {
        require(msg.sender == dataStorage.owner(), "Only DataStorage owner");
        require(_newDataStorage != address(0), "Invalid address");
        dataStorage = DataStorage(_newDataStorage);
    }
}