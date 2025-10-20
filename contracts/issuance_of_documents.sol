// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./DataStorage.sol";

contract IssuanceOfDocument {
    DataStorage public dataStorage;

    struct Document {
        string documentHash;
        uint256 studentId;
        uint256 createdAt;
        address signedBy;
        string documentType;
        bool isValid;
    }

    mapping(bytes32 => Document) public documents;
    bytes32[] public documentIds;
 
    mapping(uint256 => bytes32[]) public studentDocuments;

    event DocumentSigned(
        bytes32 indexed documentId,
        uint256 indexed studentId,
        address indexed manager,
        string documentType
    );
    event DocumentRevoked(bytes32 indexed documentId, address indexed revokedBy);

    constructor(address _dataStorage) {
        require(_dataStorage != address(0), "Invalid DataStorage address");
        dataStorage = DataStorage(_dataStorage);
    }

    modifier onlyManager() {
        require(dataStorage.isManager(msg.sender), "Only authorized managers can call this");
        _;
    }

    modifier onlyAdmin() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        require(
            role == DataStorage.Role.ADMIN || msg.sender == dataStorage.owner(),
            "Only admin can call this"
        );
        _;
    }

    function signDocument(
        string memory _documentHash,
        uint256 _studentId,
        string memory _documentType
    ) public onlyManager returns (bytes32) {
        require(bytes(_documentHash).length > 0, "Document hash required");
        require(_studentId > 0, "Invalid student ID");
        
        (uint256 id, , , , , bool isActive, ) = dataStorage.getStudent(_studentId);
        require(id != 0, "Student not found");
        require(isActive, "Student is not active");
        
        bytes32 docId = keccak256(abi.encodePacked(
            _documentHash,
            _studentId,
            block.timestamp,
            msg.sender
        ));
        
        require(documents[docId].createdAt == 0, "Document already exists");
        
        documents[docId] = Document({
            documentHash: _documentHash,
            studentId: _studentId,
            createdAt: block.timestamp,
            signedBy: msg.sender,
            documentType: _documentType,
            isValid: true
        });
        
        documentIds.push(docId);
        studentDocuments[_studentId].push(docId);
        
        emit DocumentSigned(docId, _studentId, msg.sender, _documentType);
        
        return docId;
    }

    function revokeDocument(bytes32 _documentId) external onlyAdmin {
        require(documents[_documentId].createdAt != 0, "Document does not exist");
        require(documents[_documentId].isValid, "Document already revoked");
        
        documents[_documentId].isValid = false;
        emit DocumentRevoked(_documentId, msg.sender);
    }

    function getDocumentInfo(bytes32 _documentId) public view returns (
        string memory documentHash,
        uint256 studentId,
        uint256 createdAt,
        address signedBy,
        string memory documentType,
        bool isValid
    ) {
        Document storage doc = documents[_documentId];
        require(doc.createdAt != 0, "Document does not exist");
        
        return (
            doc.documentHash,
            doc.studentId,
            doc.createdAt,
            doc.signedBy,
            doc.documentType,
            doc.isValid
        );
    }

    function getStudentDocuments(uint256 _studentId) external view returns (bytes32[] memory) {
        return studentDocuments[_studentId];
    }

    function isDocumentValid(bytes32 _documentId) external view returns (bool) {
        return documents[_documentId].isValid && documents[_documentId].createdAt != 0;
    }

    function getDocumentCount() public view returns (uint256) {
        return documentIds.length;
    }

    function hasSignedDocument(bytes32 _documentId, address _manager) public view returns (bool) {
        return documents[_documentId].signedBy == _manager;
    }

    function updateDataStorage(address _newDataStorage) external {
        require(msg.sender == dataStorage.owner(), "Only DataStorage owner");
        require(_newDataStorage != address(0), "Invalid address");
        dataStorage = DataStorage(_newDataStorage);
    }
}