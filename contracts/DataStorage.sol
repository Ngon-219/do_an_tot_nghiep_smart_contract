// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract DataStorage {
    // Custom errors for gas optimization
    error Unauthorized();
    error InvalidAddress();
    error ManagerAlreadyExists();
    error ManagerNotFound();
    error NoManagersToRemove();
    error AddressAlreadyRegistered();
    error StudentCodeAlreadyExists();
    error StudentCodeRequired();
    error ArrayLengthMismatch();
    error MaxBatchSizeExceeded();
    error StudentNotFound();
    error StudentAlreadyInactive();
    error InvalidRole();
    
    address public owner;
    
    enum Role {
        NONE,           
        STUDENT,        
        TEACHER,        
        ADMIN,          
        MANAGER          
    }
    
    struct Student {
        uint256 id;
        address walletAddress;
        string studentCode;
        string fullName;
        string email;
        bool isActive;
        uint256 registeredAt;
    }
    
    mapping(address => Role) public userRoles;
    mapping(address => bool) public isRegistered;
    
    address[] public managers;
    mapping(address => bool) public isManager;
    mapping(address => uint256) private managerIndex;
    
    mapping(uint256 => Student) public students;
    mapping(address => uint256) public addressToStudentId;
    mapping(string => uint256) public codeToStudentId;
    uint256 public nextStudentId = 1;
    uint256 public totalStudents;
    
    mapping(address => bool) public authorizedContracts;
    
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event ManagerAdded(address indexed manager);
    event ManagerRemoved(address indexed manager);
    event StudentRegistered(uint256 indexed studentId, address indexed studentAddress, string studentCode);
    event StudentDeactivated(uint256 indexed studentId);
    event RoleAssigned(address indexed user, Role role);
    event ContractAuthorized(address indexed contractAddress);
    event ContractUnauthorized(address indexed contractAddress);
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    
    modifier onlyAdmin() {
        if (userRoles[msg.sender] != Role.ADMIN && msg.sender != owner) revert Unauthorized();
        _;
    }
    
    modifier onlyAuthorized() {
        require(
            authorizedContracts[msg.sender] || msg.sender == owner,
            "Only authorized contracts can call this"
        );
        _;
    }
    
    constructor() {
        owner = msg.sender;
        userRoles[msg.sender] = Role.ADMIN;
        isRegistered[msg.sender] = true;
    }
    
    function changeOwner(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert InvalidAddress();
        address oldOwner = owner;
        owner = _newOwner;
        userRoles[_newOwner] = Role.ADMIN;
        isRegistered[_newOwner] = true;
        emit OwnerChanged(oldOwner, _newOwner);
    }
    
    function authorizeContract(address _contract) external onlyOwner {
        if (_contract == address(0)) revert InvalidAddress();
        authorizedContracts[_contract] = true;
        emit ContractAuthorized(_contract);
    }
    
    function unauthorizeContract(address _contract) external onlyOwner {
        authorizedContracts[_contract] = false;
        emit ContractUnauthorized(_contract);
    }
    
    function addManager(address _manager) external onlyAdmin {
        if (_manager == address(0)) revert InvalidAddress();
        if (isManager[_manager]) revert ManagerAlreadyExists();
        
        managerIndex[_manager] = managers.length;
        managers.push(_manager);
        isManager[_manager] = true;
        userRoles[_manager] = Role.MANAGER;
        isRegistered[_manager] = true;
        
        emit ManagerAdded(_manager);
    }
    
    function removeManager(address _manager) external onlyAdmin {
        if (!isManager[_manager]) revert ManagerNotFound();
        if (managers.length == 0) revert NoManagersToRemove();
        
        uint256 idx = managerIndex[_manager];
        address lastManager = managers[managers.length - 1];
        
        managers[idx] = lastManager;
        managerIndex[lastManager] = idx;
        
        managers.pop();
        delete isManager[_manager];
        delete managerIndex[_manager];
        userRoles[_manager] = Role.NONE;
        
        emit ManagerRemoved(_manager);
    }
    
    function getAllManagers() external view returns (address[] memory) {
        return managers;
    }
    
    function getManagerCount() external view returns (uint256) {
        return managers.length;
    }

    function registerStudent(
        address _studentAddress,
        string calldata _studentCode,
        string calldata _fullName,
        string calldata _email
    ) external onlyAdmin returns (uint256) {
        if (_studentAddress == address(0)) revert InvalidAddress();
        if (addressToStudentId[_studentAddress] != 0) revert AddressAlreadyRegistered();
        if (codeToStudentId[_studentCode] != 0) revert StudentCodeAlreadyExists();
        if (bytes(_studentCode).length == 0) revert StudentCodeRequired();
        
        uint256 studentId = nextStudentId++;
        
        students[studentId] = Student({
            id: studentId,
            walletAddress: _studentAddress,
            studentCode: _studentCode,
            fullName: _fullName,
            email: _email,
            isActive: true,
            registeredAt: block.timestamp
        });
        
        addressToStudentId[_studentAddress] = studentId;
        codeToStudentId[_studentCode] = studentId;
        userRoles[_studentAddress] = Role.STUDENT;
        isRegistered[_studentAddress] = true;
        totalStudents++;
        
        emit StudentRegistered(studentId, _studentAddress, _studentCode);
        
        return studentId;
    }
    
    function registerStudentsBatch(
        address[] calldata _addresses,
        string[] calldata _studentCodes,
        string[] calldata _fullNames,
        string[] calldata _emails
    ) external onlyAdmin {
        uint256 length = _addresses.length;
        if (length != _studentCodes.length || length != _fullNames.length || length != _emails.length) {
            revert ArrayLengthMismatch();
        }
        if (length > 50) revert MaxBatchSizeExceeded();
        
        uint256 currentId = nextStudentId;
        uint256 timestamp = block.timestamp;
        uint256 successCount;
        
        for (uint256 i = 0; i < length; ) {
            address addr = _addresses[i];
            string calldata code = _studentCodes[i];
            
            if (addressToStudentId[addr] == 0 && codeToStudentId[code] == 0) {
                uint256 studentId = currentId++;
                
                students[studentId] = Student({
                    id: studentId,
                    walletAddress: addr,
                    studentCode: code,
                    fullName: _fullNames[i],
                    email: _emails[i],
                    isActive: true,
                    registeredAt: timestamp
                });
                
                addressToStudentId[addr] = studentId;
                codeToStudentId[code] = studentId;
                userRoles[addr] = Role.STUDENT;
                isRegistered[addr] = true;
                
                emit StudentRegistered(studentId, addr, code);
                unchecked { ++successCount; }
            }
            
            unchecked { ++i; }
        }
        
        nextStudentId = currentId;
        totalStudents += successCount;
    }
    
    function deactivateStudent(uint256 _studentId) external onlyAdmin {
        if (students[_studentId].id == 0) revert StudentNotFound();
        if (!students[_studentId].isActive) revert StudentAlreadyInactive();
        
        students[_studentId].isActive = false;
        emit StudentDeactivated(_studentId);
    }

    function activateStudent(uint256 _studentId) external onlyAdmin {
        if (students[_studentId].id == 0) revert StudentNotFound();
        students[_studentId].isActive = true;
    }
    
    function getStudent(uint256 _studentId) external view returns (
        uint256 id,
        address walletAddress,
        string memory studentCode,
        string memory fullName,
        string memory email,
        bool isActive,
        uint256 registeredAt
    ) {
        Student memory student = students[_studentId];
        if (student.id == 0) revert StudentNotFound();
        
        return (
            student.id,
            student.walletAddress,
            student.studentCode,
            student.fullName,
            student.email,
            student.isActive,
            student.registeredAt
        );
    }
    
    function getStudentIdByAddress(address _address) external view returns (uint256) {
        return addressToStudentId[_address];
    }
    
    function getStudentIdByCode(string memory _studentCode) external view returns (uint256) {
        return codeToStudentId[_studentCode];
    }
    
    function isActiveStudent(address _address) external view returns (bool) {
        uint256 studentId = addressToStudentId[_address];
        if (studentId == 0) return false;
        return students[studentId].isActive;
    }

    function assignRole(address _user, Role _role) external onlyOwner {
        if (_user == address(0)) revert InvalidAddress();
        userRoles[_user] = _role;
        isRegistered[_user] = true;
        emit RoleAssigned(_user, _role);
    }
    
    function getUserRole(address _user) external view returns (Role) {
        return userRoles[_user];
    }
    
    function hasRole(address _user, Role _role) external view returns (bool) {
        return userRoles[_user] == _role;
    }
    
    function isTeacherOrAdmin(address _user) external view returns (bool) {
        return userRoles[_user] == Role.TEACHER || userRoles[_user] == Role.ADMIN || _user == owner;
    }
    
    function getTotalStudents() external view returns (uint256) {
        return totalStudents;
    }
    
    function getContractInfo() external view returns (
        address currentOwner,
        uint256 studentCount,
        uint256 managerCount
    ) {
        return (owner, totalStudents, managers.length);
    }
}