// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./DataStorage.sol";
import "./DocumentNFT.sol";

/**
 * @title IssuanceOfDocument
 * @dev Contract quản lý việc cấp phát documents dưới dạng NFT
 * Manager ký document → Mint NFT → Gửi về ví sinh viên
 */
contract IssuanceOfDocument {
    DataStorage public dataStorage;
    DocumentNFT public documentNFT;

    // Legacy document tracking (for backward compatibility)
    struct Document {
        uint256 tokenId;        // NFT token ID
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
        uint256 indexed tokenId,
        uint256 indexed studentId,
        address studentAddress,
        address manager,
        string documentType
    );
    event DocumentRevoked(bytes32 indexed documentId, uint256 indexed tokenId, address indexed revokedBy);
    event DocumentNFTUpdated(address indexed oldNFT, address indexed newNFT);

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

    /**
     * @dev Set DocumentNFT contract address (only admin, called once after deployment)
     */
    function setDocumentNFT(address _documentNFT) external onlyAdmin {
        require(_documentNFT != address(0), "Invalid DocumentNFT address");
        address oldNFT = address(documentNFT);
        documentNFT = DocumentNFT(_documentNFT);
        emit DocumentNFTUpdated(oldNFT, _documentNFT);
    }

    /**
     * @dev Sign document and mint NFT to student
     * @param _documentHash Hash của document (IPFS hash hoặc SHA256)
     * @param _studentId ID của sinh viên
     * @param _documentType Loại document (Degree, Certificate, Transcript...)
     * @param _tokenURI URI của metadata JSON (IPFS link hoặc API endpoint)
     */
    function signDocument(
        string memory _documentHash,
        uint256 _studentId,
        string memory _documentType,
        string memory _tokenURI
    ) public onlyManager returns (bytes32, uint256) {
        require(address(documentNFT) != address(0), "DocumentNFT not set");
        require(bytes(_documentHash).length > 0, "Document hash required");
        require(_studentId > 0, "Invalid student ID");
        
        // Get student info from DataStorage
        (uint256 id, address studentAddress, , , , bool isActive, ) = dataStorage.getStudent(_studentId);
        require(id != 0, "Student not found");
        require(isActive, "Student is not active");
        require(studentAddress != address(0), "Student has no wallet address");
        
        // Generate document ID
        bytes32 docId = keccak256(abi.encodePacked(
            _documentHash,
            _studentId,
            block.timestamp,
            msg.sender
        ));
        
        require(documents[docId].createdAt == 0, "Document already exists");
        
        // Mint NFT to student address
        uint256 tokenId = documentNFT.mintDocument(
            _studentId,
            studentAddress,
            _documentType,
            _documentHash,
            _tokenURI
        );
        
        // Save document info
        documents[docId] = Document({
            tokenId: tokenId,
            documentHash: _documentHash,
            studentId: _studentId,
            createdAt: block.timestamp,
            signedBy: msg.sender,
            documentType: _documentType,
            isValid: true
        });
        
        documentIds.push(docId);
        studentDocuments[_studentId].push(docId);
        
        emit DocumentSigned(docId, tokenId, _studentId, studentAddress, msg.sender, _documentType);
        
        return (docId, tokenId);
    }

    /**
     * @dev Revoke document (revoke NFT validity, but NFT still exists in student wallet)
     */
    function revokeDocument(bytes32 _documentId) external onlyAdmin {
        require(documents[_documentId].createdAt != 0, "Document does not exist");
        require(documents[_documentId].isValid, "Document already revoked");
        
        // Mark document as invalid
        documents[_documentId].isValid = false;
        
        // Revoke NFT
        uint256 tokenId = documents[_documentId].tokenId;
        if (tokenId > 0) {
            documentNFT.revokeDocument(tokenId);
        }
        
        emit DocumentRevoked(_documentId, tokenId, msg.sender);
    }

    /**
     * @dev Reactivate revoked document
     */
    function reactivateDocument(bytes32 _documentId) external onlyAdmin {
        require(documents[_documentId].createdAt != 0, "Document does not exist");
        require(!documents[_documentId].isValid, "Document is already valid");
        
        documents[_documentId].isValid = true;
        
        uint256 tokenId = documents[_documentId].tokenId;
        if (tokenId > 0) {
            documentNFT.reactivateDocument(tokenId);
        }
    }

    /**
     * @dev Get document info by document ID
     */
    function getDocumentInfo(bytes32 _documentId) public view returns (
        uint256 tokenId,
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
            doc.tokenId,
            doc.documentHash,
            doc.studentId,
            doc.createdAt,
            doc.signedBy,
            doc.documentType,
            doc.isValid
        );
    }

    /**
     * @dev Get document info by NFT token ID
     */
    function getDocumentInfoByTokenId(uint256 _tokenId) external view returns (
        string memory documentHash,
        uint256 studentId,
        uint256 createdAt,
        address signedBy,
        string memory documentType,
        bool isValid
    ) {
        require(address(documentNFT) != address(0), "DocumentNFT not set");
        
        (
            uint256 sid,
            string memory dtype,
            string memory dhash,
            uint256 issuedAt,
            address issuedBy,
            bool valid
        ) = documentNFT.getDocumentMetadata(_tokenId);
        
        return (dhash, sid, issuedAt, issuedBy, dtype, valid);
    }

    /**
     * @dev Get all document IDs of a student
     */
    function getStudentDocuments(uint256 _studentId) external view returns (bytes32[] memory) {
        return studentDocuments[_studentId];
    }

    /**
     * @dev Get all NFT token IDs of a student
     */
    function getStudentNFTs(uint256 _studentId) external view returns (uint256[] memory) {
        require(address(documentNFT) != address(0), "DocumentNFT not set");
        return documentNFT.getStudentTokens(_studentId);
    }

    /**
     * @dev Check if document is valid
     */
    function isDocumentValid(bytes32 _documentId) external view returns (bool) {
        if (documents[_documentId].createdAt == 0) return false;
        return documents[_documentId].isValid;
    }

    /**
     * @dev Check if NFT is valid
     */
    function isNFTValid(uint256 _tokenId) external view returns (bool) {
        require(address(documentNFT) != address(0), "DocumentNFT not set");
        return documentNFT.isDocumentValid(_tokenId);
    }

    /**
     * @dev Get total document count
     */
    function getDocumentCount() public view returns (uint256) {
        return documentIds.length;
    }

    /**
     * @dev Check if manager has signed a document
     */
    function hasSignedDocument(bytes32 _documentId, address _manager) public view returns (bool) {
        return documents[_documentId].signedBy == _manager;
    }

    /**
     * @dev Get DocumentNFT contract address
     */
    function getDocumentNFTAddress() external view returns (address) {
        return address(documentNFT);
    }

    /**
     * @dev Update DataStorage address (only owner)
     */
    function updateDataStorage(address _newDataStorage) external {
        require(msg.sender == dataStorage.owner(), "Only DataStorage owner");
        require(_newDataStorage != address(0), "Invalid address");
        dataStorage = DataStorage(_newDataStorage);
    }
}