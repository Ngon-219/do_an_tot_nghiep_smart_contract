// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DataStorage.sol";

contract DocumentNFT is ERC721URIStorage, Ownable {
    // Custom errors for gas optimization
    error InvalidDataStorage();
    error InvalidStudentAddress();
    error DocumentHashRequired();
    error DocumentAlreadyMinted();
    error TokenDoesNotExist();
    error DocumentAlreadyRevoked();
    error DocumentAlreadyValid();
    error InvalidAddress();
    
    DataStorage public dataStorage;
    
    uint256 private _nextTokenId = 1;

    struct DocumentMetadata {
        uint256 studentId;
        string documentType;
        string documentHash;
        uint256 issuedAt;
        address issuedBy;
        bool isValid;
    }
    
    mapping(uint256 => DocumentMetadata) public documentMetadata;
    
    mapping(uint256 => uint256[]) public studentTokens;
    
    mapping(bytes32 => uint256) public hashToTokenId;
    
    event DocumentMinted(
        uint256 indexed tokenId,
        uint256 indexed studentId,
        address indexed studentAddress,
        string documentType,
        string tokenURI
    );
    
    event DocumentRevoked(
        uint256 indexed tokenId,
        address indexed revokedBy
    );
    
    event DocumentReactivated(
        uint256 indexed tokenId,
        address indexed reactivatedBy
    );
    
    constructor(
        address _dataStorage,
        address initialOwner
    ) ERC721("Education Document NFT", "EDUDOC") Ownable(initialOwner) {
        if (_dataStorage == address(0)) revert InvalidDataStorage();
        dataStorage = DataStorage(_dataStorage);
    }
    
    function mintDocument(
        uint256 _studentId,
        address _studentAddress,
        string calldata _documentType,
        string calldata _documentHash,
        string calldata _tokenURI
    ) external onlyOwner returns (uint256) {
        if (_studentAddress == address(0)) revert InvalidStudentAddress();
        if (bytes(_documentHash).length == 0) revert DocumentHashRequired();
        
        bytes32 hashKey = keccak256(abi.encodePacked(_documentHash, _studentId));
        if (hashToTokenId[hashKey] != 0) revert DocumentAlreadyMinted();
        
        uint256 tokenId = _nextTokenId++;
        
        _safeMint(_studentAddress, tokenId);
        
        if (bytes(_tokenURI).length > 0) {
            _setTokenURI(tokenId, _tokenURI);
        }
        
        documentMetadata[tokenId] = DocumentMetadata({
            studentId: _studentId,
            documentType: _documentType,
            documentHash: _documentHash,
            issuedAt: block.timestamp,
            issuedBy: tx.origin,
            isValid: true
        });
        
        studentTokens[_studentId].push(tokenId);
        hashToTokenId[hashKey] = tokenId;
        
        emit DocumentMinted(tokenId, _studentId, _studentAddress, _documentType, _tokenURI);
        
        return tokenId;
    }
    
    function revokeDocument(uint256 _tokenId) external onlyOwner {
        if (_ownerOf(_tokenId) == address(0)) revert TokenDoesNotExist();
        if (!documentMetadata[_tokenId].isValid) revert DocumentAlreadyRevoked();
        
        documentMetadata[_tokenId].isValid = false;
        
        emit DocumentRevoked(_tokenId, msg.sender);
    }
    
    function reactivateDocument(uint256 _tokenId) external onlyOwner {
        if (_ownerOf(_tokenId) == address(0)) revert TokenDoesNotExist();
        if (documentMetadata[_tokenId].isValid) revert DocumentAlreadyValid();
        
        documentMetadata[_tokenId].isValid = true;
        
        emit DocumentReactivated(_tokenId, msg.sender);
    }
    
    function getDocumentMetadata(uint256 _tokenId) external view returns (
        uint256 studentId,
        string memory documentType,
        string memory documentHash,
        uint256 issuedAt,
        address issuedBy,
        bool isValid
    ) {
        if (_ownerOf(_tokenId) == address(0)) revert TokenDoesNotExist();
        DocumentMetadata memory metadata = documentMetadata[_tokenId];
        
        return (
            metadata.studentId,
            metadata.documentType,
            metadata.documentHash,
            metadata.issuedAt,
            metadata.issuedBy,
            metadata.isValid
        );
    }
    
    function getStudentTokens(uint256 _studentId) external view returns (uint256[] memory) {
        return studentTokens[_studentId];
    }
    
    function isDocumentValid(uint256 _tokenId) external view returns (bool) {
        if (_ownerOf(_tokenId) == address(0)) return false;
        return documentMetadata[_tokenId].isValid;
    }
    
    function getTokenIdByHash(string calldata _documentHash, uint256 _studentId) external view returns (uint256) {
        bytes32 hashKey = keccak256(abi.encodePacked(_documentHash, _studentId));
        return hashToTokenId[hashKey];
    }
    
    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }
    
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        return super._update(to, tokenId, auth);
    }
    
    function updateDataStorage(address _newDataStorage) external onlyOwner {
        if (_newDataStorage == address(0)) revert InvalidAddress();
        dataStorage = DataStorage(_newDataStorage);
    }
}
