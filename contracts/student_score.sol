// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./DataStorage.sol";

contract StudentViolation {
    DataStorage public dataStorage;

    struct ViolationDetail {
        uint256 points;
        uint256 lastUpdated;
        address lastUpdatedBy;
    }

    // studentId => semester => ViolationDetail
    mapping(uint256 => mapping(string => ViolationDetail)) public violations;

    event ViolationInitialized(
        uint256 indexed studentId,
        string semester,
        uint256 points,
        address indexed setBy
    );
    event ViolationUpdated(
        uint256 indexed studentId,
        string semester,
        uint256 oldPoints,
        uint256 newPoints,
        address indexed updatedBy
    );
    event ViolationReset(
        uint256 indexed studentId,
        string semester,
        uint256 oldPoints,
        uint256 newPoints,
        address indexed resetBy
    );
    event AllViolationsReset(
        string semester,
        uint256 resetValue,
        address indexed resetBy
    );

    constructor(address _dataStorage) {
        require(_dataStorage != address(0), "Invalid DataStorage address");
        dataStorage = DataStorage(_dataStorage);
    }

    modifier onlyManagerTeacherOrAdmin() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        require(
            role == DataStorage.Role.MANAGER ||
            role == DataStorage.Role.TEACHER ||
            role == DataStorage.Role.ADMIN ||
            msg.sender == dataStorage.owner(),
            "Only manager, teacher, or admin can modify violations"
        );
        _;
    }

    modifier onlyActiveStudent(uint256 _studentId) {
        require(_studentId > 0, "Invalid student ID");
        (uint256 id, , , , , bool isActive, ) = dataStorage.getStudent(_studentId);
        require(id != 0, "Student not found");
        require(isActive, "Student is not active");
        _;
    }

    function initializeViolation(
        uint256 _studentId,
        string memory _semester,
        uint256 _points
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        require(bytes(_semester).length > 0, "Semester required");
        require(violations[_studentId][_semester].lastUpdated == 0, "Violation already initialized for this semester");
        require(_points <= 100, "Points must be between 0 and 100");
        
        violations[_studentId][_semester] = ViolationDetail({
            points: _points,
            lastUpdated: block.timestamp,
            lastUpdatedBy: msg.sender
        });

        emit ViolationInitialized(_studentId, _semester, _points, msg.sender);
    }

    function addPoints(
        uint256 _studentId,
        string memory _semester,
        uint256 _increment
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        require(bytes(_semester).length > 0, "Semester required");
        ViolationDetail storage violation = violations[_studentId][_semester];
        require(violation.lastUpdated > 0, "Violation not initialized for this semester");
        
        uint256 oldPoints = violation.points;
        uint256 newPoints = oldPoints + _increment;
        
        if (newPoints > 100) {
            newPoints = 100;
        }
        
        violation.points = newPoints;
        violation.lastUpdated = block.timestamp;
        violation.lastUpdatedBy = msg.sender;
        
        emit ViolationUpdated(_studentId, _semester, oldPoints, newPoints, msg.sender);
    }

    function subtractPoints(
        uint256 _studentId,
        string memory _semester,
        uint256 _decrement
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        require(bytes(_semester).length > 0, "Semester required");
        ViolationDetail storage violation = violations[_studentId][_semester];
        require(violation.lastUpdated > 0, "Violation not initialized for this semester");
        
        uint256 oldPoints = violation.points;
        uint256 newPoints;
        
        if (oldPoints < _decrement) {
            newPoints = 0;
        } else {
            newPoints = oldPoints - _decrement;
        }
        
        violation.points = newPoints;
        violation.lastUpdated = block.timestamp;
        violation.lastUpdatedBy = msg.sender;
        
        emit ViolationUpdated(_studentId, _semester, oldPoints, newPoints, msg.sender);
    }

    function resetStudent(
        uint256 _studentId,
        string memory _semester,
        uint256 _newPoints
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        require(bytes(_semester).length > 0, "Semester required");
        require(_newPoints <= 100, "Points must be between 0 and 100");
        
        ViolationDetail storage violation = violations[_studentId][_semester];
        require(violation.lastUpdated > 0, "Violation not initialized for this semester");
        
        uint256 oldPoints = violation.points;
        
        violation.points = _newPoints;
        violation.lastUpdated = block.timestamp;
        violation.lastUpdatedBy = msg.sender;
        
        emit ViolationReset(_studentId, _semester, oldPoints, _newPoints, msg.sender);
    }

    function resetAllStudents(
        string memory _semester,
        uint256 _newPoints
    ) external onlyManagerTeacherOrAdmin {
        require(bytes(_semester).length > 0, "Semester required");
        require(_newPoints <= 100, "Points must be between 0 and 100");
        
        uint256 totalStudents = dataStorage.getTotalStudents();
        
        for (uint256 i = 1; i <= totalStudents; i++) {
            (uint256 id, , , , , bool isActive, ) = dataStorage.getStudent(i);
            
            if (id != 0 && isActive && violations[i][_semester].lastUpdated > 0) {
                uint256 oldPoints = violations[i][_semester].points;
                violations[i][_semester].points = _newPoints;
                violations[i][_semester].lastUpdated = block.timestamp;
                violations[i][_semester].lastUpdatedBy = msg.sender;
                
                emit ViolationReset(i, _semester, oldPoints, _newPoints, msg.sender);
            }
        }
        
        emit AllViolationsReset(_semester, _newPoints, msg.sender);
    }

    function getViolation(
        uint256 _studentId,
        string memory _semester
    ) external view returns (
        uint256 points,
        uint256 lastUpdated,
        address lastUpdatedBy
    ) {
        require(dataStorage.isRegistered(msg.sender), "Only registered users can view violations");
        ViolationDetail memory violation = violations[_studentId][_semester];
        
        return (
            violation.points,
            violation.lastUpdated,
            violation.lastUpdatedBy
        );
    }

    function getPoints(
        uint256 _studentId,
        string memory _semester
    ) external view returns (uint256) {
        require(dataStorage.isRegistered(msg.sender), "Only registered users can view violations");
        return violations[_studentId][_semester].points;
    }

    function updateDataStorage(address _newDataStorage) external {
        require(msg.sender == dataStorage.owner(), "Only DataStorage owner");
        require(_newDataStorage != address(0), "Invalid address");
        dataStorage = DataStorage(_newDataStorage);
    }
}