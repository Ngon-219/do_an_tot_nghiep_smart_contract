// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract DataStorage {
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
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    modifier onlyAdmin() {
        require(userRoles[msg.sender] == Role.ADMIN || msg.sender == owner, "Only admin can call this");
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
        require(_newOwner != address(0), "Invalid address");
        address oldOwner = owner;
        owner = _newOwner;
        userRoles[_newOwner] = Role.ADMIN;
        isRegistered[_newOwner] = true;
        emit OwnerChanged(oldOwner, _newOwner);
    }
    
    function authorizeContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Invalid address");
        authorizedContracts[_contract] = true;
        emit ContractAuthorized(_contract);
    }
    
    function unauthorizeContract(address _contract) external onlyOwner {
        authorizedContracts[_contract] = false;
        emit ContractUnauthorized(_contract);
    }
    
    function addManager(address _manager) external onlyAdmin {
        require(_manager != address(0), "Invalid address");
        require(!isManager[_manager], "Manager already exists");
        
        managerIndex[_manager] = managers.length;
        managers.push(_manager);
        isManager[_manager] = true;
        userRoles[_manager] = Role.MANAGER;
        isRegistered[_manager] = true;
        
        emit ManagerAdded(_manager);
    }
    
    function removeManager(address _manager) external onlyAdmin {
        require(isManager[_manager], "Manager not found");
        require(managers.length > 0, "No managers to remove");
        
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
        string memory _studentCode,
        string memory _fullName,
        string memory _email
    ) external onlyAdmin returns (uint256) {
        require(_studentAddress != address(0), "Invalid address");
        require(addressToStudentId[_studentAddress] == 0, "Address already registered");
        require(codeToStudentId[_studentCode] == 0, "Student code already exists");
        require(bytes(_studentCode).length > 0, "Student code required");
        
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
        address[] memory _addresses,
        string[] memory _studentCodes,
        string[] memory _fullNames,
        string[] memory _emails
    ) external onlyAdmin {
        require(_addresses.length == _studentCodes.length, "Array length mismatch");
        require(_addresses.length == _fullNames.length, "Array length mismatch");
        require(_addresses.length == _emails.length, "Array length mismatch");
        require(_addresses.length <= 50, "Maximum 50 students per batch");
        
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (addressToStudentId[_addresses[i]] == 0 && codeToStudentId[_studentCodes[i]] == 0) {
                uint256 studentId = nextStudentId++;
                
                students[studentId] = Student({
                    id: studentId,
                    walletAddress: _addresses[i],
                    studentCode: _studentCodes[i],
                    fullName: _fullNames[i],
                    email: _emails[i],
                    isActive: true,
                    registeredAt: block.timestamp
                });
                
                addressToStudentId[_addresses[i]] = studentId;
                codeToStudentId[_studentCodes[i]] = studentId;
                userRoles[_addresses[i]] = Role.STUDENT;
                isRegistered[_addresses[i]] = true;
                totalStudents++;
                
                emit StudentRegistered(studentId, _addresses[i], _studentCodes[i]);
            }
        }
    }
    
    function deactivateStudent(uint256 _studentId) external onlyAdmin {
        require(students[_studentId].id != 0, "Student not found");
        require(students[_studentId].isActive, "Student already inactive");
        
        students[_studentId].isActive = false;
        emit StudentDeactivated(_studentId);
    }

    function activateStudent(uint256 _studentId) external onlyAdmin {
        require(students[_studentId].id != 0, "Student not found");
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
        require(student.id != 0, "Student not found");
        
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
        require(_user != address(0), "Invalid address");
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