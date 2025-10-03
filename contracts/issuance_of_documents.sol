// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract IssuanceOfDocument {
    address public owner;
    address[] public signers;
    
    mapping(address => bool) public isSigner;
    mapping(address => uint) private signerIndex;

    // Document structure
    struct Document {
        string documentHash;
        uint256 createdAt;
        address signedBy;
    }

    mapping(bytes32 => Document) public documents;
    bytes32[] public documentIds;

    // Events
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event DocumentSigned(bytes32 indexed documentId, address indexed signer);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier onlySigner() {
        require(isSigner[msg.sender], "Only authorized signers can call this");
        _;
    }

    //handle signer
    
    function addSigner(address _signer) public onlyOwner {
        require(_signer != address(0), "Invalid address");
        require(!isSigner[_signer], "Signer already exists");
        
        signerIndex[_signer] = signers.length;
        signers.push(_signer);
        isSigner[_signer] = true;
        
        emit SignerAdded(_signer);
    }

    function deleteSigner(address _signer) public onlyOwner {
        require(isSigner[_signer], "Signer not found");
        require(signers.length > 1, "At least one signer required");
        
        uint idx = signerIndex[_signer];
        address lastSigner = signers[signers.length - 1];
        
        signers[idx] = lastSigner;
        signerIndex[lastSigner] = idx;
        
        signers.pop();
        delete isSigner[_signer];
        delete signerIndex[_signer];
        
        emit SignerRemoved(_signer);
    }

    function getAllSigners() public view returns (address[] memory) {
        return signers;
    }

    function countSigners() public view returns (uint) {
        return signers.length;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnerChanged(oldOwner, _newOwner);
    }

    // handle document

    function signDocument(string memory _documentHash) public onlySigner {
        bytes32 docId = keccak256(abi.encodePacked(_documentHash));
        
        require(documents[docId].createdAt == 0, "Document already exists");
        
        Document storage doc = documents[docId];
        doc.documentHash = _documentHash;
        doc.createdAt = block.timestamp;
        
        documentIds.push(docId);
        
        doc.signedBy = msg.sender;
        
        emit DocumentSigned(docId, msg.sender);
    }

    function getDocumentInfo(bytes32 _documentId) public view returns (
        string memory documentHash,
        uint256 createdAt,
        address signedBy
    ) {
        Document storage doc = documents[_documentId];
        require(doc.createdAt != 0, "Document does not exist");
        
        return (
            doc.documentHash,
            doc.createdAt,
            doc.signedBy
        );
    }

    function hasSignedDocument(bytes32 _documentId, address _signer) public view returns (bool) {
        return documents[_documentId].signedBy == _signer;
    }

    function getDocumentCount() public view returns (uint) {
        return documentIds.length;
    }
}