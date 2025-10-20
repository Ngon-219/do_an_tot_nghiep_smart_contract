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
    // Custom errors for gas optimization
    error InvalidDataStorage();
    error Unauthorized();
    error InvalidDocumentNFT();
    error DocumentNFTNotSet();
    error DocumentHashRequired();
    error InvalidStudentId();
    error StudentNotFound();
    error StudentNotActive();
    error StudentHasNoWallet();
    error DocumentAlreadyExists();
    error DocumentNotFound();
    error DocumentAlreadyRevoked();
    error DocumentAlreadyValid();
    
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
        if (_dataStorage == address(0)) revert InvalidDataStorage();
        dataStorage = DataStorage(_dataStorage);
    }

    modifier onlyManager() {
        if (!dataStorage.isManager(msg.sender)) revert Unauthorized();
        _;
    }

    modifier onlyAdmin() {
        DataStorage.Role role = dataStorage.getUserRole(msg.sender);
        if (role != DataStorage.Role.ADMIN && msg.sender != dataStorage.owner()) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @dev Set DocumentNFT contract address (only admin, called once after deployment)
     */
    function setDocumentNFT(address _documentNFT) external onlyAdmin {
        if (_documentNFT == address(0)) revert InvalidDocumentNFT();
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
        string calldata _documentHash,
        uint256 _studentId,
        string calldata _documentType,
        string calldata _tokenURI
    ) public onlyManager returns (bytes32, uint256) {
        if (address(documentNFT) == address(0)) revert DocumentNFTNotSet();
        if (bytes(_documentHash).length == 0) revert DocumentHashRequired();
        if (_studentId == 0) revert InvalidStudentId();
        
        // Get student info from DataStorage
        (uint256 id, address studentAddress, , , , bool isActive, ) = dataStorage.getStudent(_studentId);
        if (id == 0) revert StudentNotFound();
        if (!isActive) revert StudentNotActive();
        if (studentAddress == address(0)) revert StudentHasNoWallet();
        
        // Generate document ID
        bytes32 docId = keccak256(abi.encodePacked(
            _documentHash,
            _studentId,
            block.timestamp,
            msg.sender
        ));
        
        if (documents[docId].createdAt != 0) revert DocumentAlreadyExists();
        
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
        if (documents[_documentId].createdAt == 0) revert DocumentNotFound();
        if (!documents[_documentId].isValid) revert DocumentAlreadyRevoked();
        
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
        if (documents[_documentId].createdAt == 0) revert DocumentNotFound();
        if (documents[_documentId].isValid) revert DocumentAlreadyValid();
        
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
        if (doc.createdAt == 0) revert DocumentNotFound();
        
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
        if (address(documentNFT) == address(0)) revert DocumentNFTNotSet();
        
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
        if (address(documentNFT) == address(0)) revert DocumentNFTNotSet();
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
        if (address(documentNFT) == address(0)) revert DocumentNFTNotSet();
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
        if (msg.sender != dataStorage.owner()) revert Unauthorized();
        if (_newDataStorage == address(0)) revert InvalidDataStorage();
        dataStorage = DataStorage(_newDataStorage);
    }
}