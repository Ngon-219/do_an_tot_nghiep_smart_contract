// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./DataStorage.sol";

contract VotingContract {
    // Custom errors for gas optimization
    error InvalidDataStorage();
    error Unauthorized();
    error EventNameRequired();
    error MinimumTwoOptions();
    error InvalidDuration();
    error EventNotFound();
    error EventAlreadyClosed();
    error EventClosed();
    error VotingPeriodEnded();
    error AlreadyVoted();
    error NotVoted();
    error InvalidOption();
    error SameOption();
    error UserHasNotVoted();
    
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
    event VoteChanged(
        uint256 indexed eventId,
        address indexed voter,
        string oldOption,
        string newOption
    );
    event VotingEventClosed(uint256 indexed eventId, address indexed closedBy);

    constructor(address _dataStorage) {
        if (_dataStorage == address(0)) revert InvalidDataStorage();
        dataStorage = DataStorage(_dataStorage);
    }

    modifier onlyAdmin() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        if (role != DataStorage.Role.ADMIN && msg.sender != dataStorage.owner()) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyManagerOrTeacher() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        if (role != DataStorage.Role.MANAGER && 
            role != DataStorage.Role.TEACHER &&
            role != DataStorage.Role.ADMIN &&
            msg.sender != dataStorage.owner()) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyActiveStudent() {
        if (!dataStorage.isActiveStudent(msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    function createVotingEvent(
        string calldata _name,
        string calldata _description,
        string[] calldata _options,
        uint256 _durationInDays
    ) external onlyManagerOrTeacher returns (uint256) {
        if (bytes(_name).length == 0) revert EventNameRequired();
        if (_options.length < 2) revert MinimumTwoOptions();
        if (_durationInDays == 0 || _durationInDays > 365) revert InvalidDuration();

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

        uint256 length = _options.length;
        for (uint256 i = 0; i < length; ) {
            voteScores[eventId][_options[i]] = 0;
            unchecked { ++i; }
        }

        emit VotingEventCreated(eventId, _name, msg.sender, endTime);
        return eventId;
    }

    function closeVotingEvent(uint256 _eventId) external {
        VotingEvent storage ve = votingEvents[_eventId];
        if (ve.createdAt == 0) revert EventNotFound();
        if (!ve.isActive) revert EventAlreadyClosed();
        
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        if (msg.sender != ve.createdBy && 
            role != DataStorage.Role.MANAGER &&
            role != DataStorage.Role.TEACHER &&
            role != DataStorage.Role.ADMIN &&
            msg.sender != dataStorage.owner()) {
            revert Unauthorized();
        }

        ve.isActive = false;
        emit VotingEventClosed(_eventId, msg.sender);
    }

    function vote(uint256 _eventId, string calldata _option) external onlyActiveStudent {
        VotingEvent storage ve = votingEvents[_eventId];
        
        if (ve.createdAt == 0) revert EventNotFound();
        if (!ve.isActive) revert EventClosed();
        if (block.timestamp >= ve.endTime) revert VotingPeriodEnded();
        if (hasVoted[_eventId][msg.sender]) revert AlreadyVoted();
        
        bool optionExists = false;
        uint256 length = ve.options.length;
        for (uint256 i = 0; i < length; ) {
            if (keccak256(bytes(ve.options[i])) == keccak256(bytes(_option))) {
                optionExists = true;
                break;
            }
            unchecked { ++i; }
        }
        if (!optionExists) revert InvalidOption();

        hasVoted[_eventId][msg.sender] = true;
        userVoteChoice[_eventId][msg.sender] = _option;
        voteScores[_eventId][_option]++;
        ve.totalVotes++;

        emit VoteCast(_eventId, msg.sender, _option);
    }

    function changeVote(uint256 _eventId, string calldata _newOption) external onlyActiveStudent {
        VotingEvent storage ve = votingEvents[_eventId];
        
        if (ve.createdAt == 0) revert EventNotFound();
        if (!ve.isActive) revert EventClosed();
        if (block.timestamp >= ve.endTime) revert VotingPeriodEnded();
        if (!hasVoted[_eventId][msg.sender]) revert NotVoted();
        
        // Validate new option exists
        bool optionExists = false;
        uint256 length = ve.options.length;
        for (uint256 i = 0; i < length; ) {
            if (keccak256(bytes(ve.options[i])) == keccak256(bytes(_newOption))) {
                optionExists = true;
                break;
            }
            unchecked { ++i; }
        }
        if (!optionExists) revert InvalidOption();
        
        // Get old vote
        string memory oldOption = userVoteChoice[_eventId][msg.sender];
        
        // Prevent voting for same option
        if (keccak256(bytes(oldOption)) == keccak256(bytes(_newOption))) {
            revert SameOption();
        }
        
        // Update vote counts
        voteScores[_eventId][oldOption]--;
        voteScores[_eventId][_newOption]++;
        
        // Update user's choice
        userVoteChoice[_eventId][msg.sender] = _newOption;
        
        emit VoteChanged(_eventId, msg.sender, oldOption, _newOption);
    }

    function getVoteCount(uint256 _eventId, string calldata _option) external view returns (uint256) {
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
        if (!hasVoted[_eventId][_user]) revert UserHasNotVoted();
        return userVoteChoice[_eventId][_user];
    }

    function getVotingResults(uint256 _eventId) external view returns (
        string[] memory options,
        uint256[] memory votes
    ) {
        VotingEvent storage ve = votingEvents[_eventId];
        if (ve.createdAt == 0) revert EventNotFound();
        
        uint256 optionCount = ve.options.length;
        string[] memory eventOptions = new string[](optionCount);
        uint256[] memory voteCounts = new uint256[](optionCount);
        
        for (uint256 i = 0; i < optionCount; ) {
            eventOptions[i] = ve.options[i];
            voteCounts[i] = voteScores[_eventId][ve.options[i]];
            unchecked { ++i; }
        }
        
        return (eventOptions, voteCounts);
    }

    function getTotalEvents() external view returns (uint256) {
        return eventCount;
    }

    function updateDataStorage(address _newDataStorage) external {
        if (msg.sender != dataStorage.owner()) revert Unauthorized();
        if (_newDataStorage == address(0)) revert InvalidDataStorage();
        dataStorage = DataStorage(_newDataStorage);
    }
}