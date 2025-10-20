// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./DataStorage.sol";

contract StudentViolation {
    // Custom errors for gas optimization
    error InvalidDataStorage();
    error Unauthorized();
    error InvalidStudentId();
    error StudentNotFound();
    error StudentNotActive();
    error SemesterRequired();
    error ViolationAlreadyInitialized();
    error PointsOutOfRange();
    error ViolationNotInitialized();
    error NotAuthorizedToView();
    error InvalidRange();
    error MaxBatchSizeExceeded();
    
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
        if (_dataStorage == address(0)) revert InvalidDataStorage();
        dataStorage = DataStorage(_dataStorage);
    }

    modifier onlyManagerTeacherOrAdmin() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        if (role != DataStorage.Role.MANAGER &&
            role != DataStorage.Role.TEACHER &&
            role != DataStorage.Role.ADMIN &&
            msg.sender != dataStorage.owner()) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyActiveStudent(uint256 _studentId) {
        if (_studentId == 0) revert InvalidStudentId();
        (uint256 id, , , , , bool isActive, ) = dataStorage.getStudent(_studentId);
        if (id == 0) revert StudentNotFound();
        if (!isActive) revert StudentNotActive();
        _;
    }

    function initializeViolation(
        uint256 _studentId,
        string calldata _semester,
        uint256 _points
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        if (bytes(_semester).length == 0) revert SemesterRequired();
        if (violations[_studentId][_semester].lastUpdated != 0) revert ViolationAlreadyInitialized();
        if (_points > 100) revert PointsOutOfRange();
        
        violations[_studentId][_semester] = ViolationDetail({
            points: _points,
            lastUpdated: block.timestamp,
            lastUpdatedBy: msg.sender
        });

        emit ViolationInitialized(_studentId, _semester, _points, msg.sender);
    }

    function addPoints(
        uint256 _studentId,
        string calldata _semester,
        uint256 _increment
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        if (bytes(_semester).length == 0) revert SemesterRequired();
        ViolationDetail storage violation = violations[_studentId][_semester];
        if (violation.lastUpdated == 0) revert ViolationNotInitialized();
        
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
        string calldata _semester,
        uint256 _decrement
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        if (bytes(_semester).length == 0) revert SemesterRequired();
        ViolationDetail storage violation = violations[_studentId][_semester];
        if (violation.lastUpdated == 0) revert ViolationNotInitialized();
        
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
        string calldata _semester,
        uint256 _newPoints
    ) external onlyManagerTeacherOrAdmin onlyActiveStudent(_studentId) {
        if (bytes(_semester).length == 0) revert SemesterRequired();
        if (_newPoints > 100) revert PointsOutOfRange();
        
        ViolationDetail storage violation = violations[_studentId][_semester];
        if (violation.lastUpdated == 0) revert ViolationNotInitialized();
        
        uint256 oldPoints = violation.points;
        
        violation.points = _newPoints;
        violation.lastUpdated = block.timestamp;
        violation.lastUpdatedBy = msg.sender;
        
        emit ViolationReset(_studentId, _semester, oldPoints, _newPoints, msg.sender);
    }

    function resetAllStudents(
        string calldata _semester,
        uint256 _newPoints
    ) external onlyManagerTeacherOrAdmin {
        if (bytes(_semester).length == 0) revert SemesterRequired();
        if (_newPoints > 100) revert PointsOutOfRange();
        
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

    // NEW: Batch reset with pagination to prevent out-of-gas
    function resetStudentsBatch(
        string calldata _semester,
        uint256 _newPoints,
        uint256 _startId,
        uint256 _endId
    ) external onlyManagerTeacherOrAdmin {
        if (bytes(_semester).length == 0) revert SemesterRequired();
        if (_newPoints > 100) revert PointsOutOfRange();
        if (_endId < _startId) revert InvalidRange();
        if (_endId - _startId > 50) revert MaxBatchSizeExceeded();
        
        for (uint256 i = _startId; i <= _endId; ) {
            (uint256 id, , , , , bool isActive, ) = dataStorage.getStudent(i);
            
            if (id != 0 && isActive && violations[i][_semester].lastUpdated > 0) {
                uint256 oldPoints = violations[i][_semester].points;
                violations[i][_semester].points = _newPoints;
                violations[i][_semester].lastUpdated = block.timestamp;
                violations[i][_semester].lastUpdatedBy = msg.sender;
                
                emit ViolationReset(i, _semester, oldPoints, _newPoints, msg.sender);
            }
            
            unchecked { ++i; }
        }
    }

    function getViolation(
        uint256 _studentId,
        string calldata _semester
    ) external view returns (
        uint256 points,
        uint256 lastUpdated,
        address lastUpdatedBy
    ) {
        // Check authorization: student can view their own, teacher/admin/manager can view all
        uint256 callerStudentId = dataStorage.getStudentIdByAddress(msg.sender);
        bool isAuthorized = false;
        
        if (callerStudentId == _studentId) {
            // Student viewing their own violation
            isAuthorized = true;
        } else {
            // Check if caller is teacher, admin, or manager
            DataStorage.Role role = dataStorage.getUserRole(msg.sender);
            if (role == DataStorage.Role.TEACHER || 
                role == DataStorage.Role.ADMIN || 
                role == DataStorage.Role.MANAGER ||
                msg.sender == dataStorage.owner()) {
                isAuthorized = true;
            }
        }
        
        require(isAuthorized, "Not authorized to view this student's violations");
        
        ViolationDetail memory violation = violations[_studentId][_semester];
        
        return (
            violation.points,
            violation.lastUpdated,
            violation.lastUpdatedBy
        );
    }

    function getPoints(
        uint256 _studentId,
        string calldata _semester
    ) external view returns (uint256) {
        // Same authorization logic as getViolation
        uint256 callerStudentId = dataStorage.getStudentIdByAddress(msg.sender);
        bool isAuthorized = false;
        
        if (callerStudentId == _studentId) {
            isAuthorized = true;
        } else {
            DataStorage.Role role = dataStorage.getUserRole(msg.sender);
            if (role == DataStorage.Role.TEACHER || 
                role == DataStorage.Role.ADMIN || 
                role == DataStorage.Role.MANAGER ||
                msg.sender == dataStorage.owner()) {
                isAuthorized = true;
            }
        }
        
        if (!isAuthorized) revert NotAuthorizedToView();
        
        return violations[_studentId][_semester].points;
    }

    function updateDataStorage(address _newDataStorage) external {
        if (msg.sender != dataStorage.owner()) revert Unauthorized();
        if (_newDataStorage == address(0)) revert InvalidDataStorage();
        dataStorage = DataStorage(_newDataStorage);
    }
}