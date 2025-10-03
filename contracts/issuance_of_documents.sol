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
        address issuer;
        uint256 issuedAt;
        mapping(address => bool) signatures;
        address signedBy;
        bool isFinalized;
    }

    mapping(bytes32 => Document) public documents;
    bytes32[] public documentIds;

    // Events
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event DocumentIssued(bytes32 indexed documentId, string documentHash, address indexed issuer);
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
    
    function issueDocument(string memory _documentHash) public onlyOwner returns (bytes32) {
        bytes32 docId = keccak256(abi.encodePacked(_documentHash, block.timestamp, msg.sender));
        
        require(documents[docId].issuedAt == 0, "Document already exists");
        
        Document storage doc = documents[docId];
        doc.documentHash = _documentHash;
        doc.issuer = msg.sender;
        doc.issuedAt = block.timestamp;
        doc.isFinalized = false;
        
        documentIds.push(docId);
        
        emit DocumentIssued(docId, _documentHash, msg.sender);
        return docId;
    }

    function signDocument(bytes32 _documentId) public onlySigner {
        Document storage doc = documents[_documentId];
        
        require(doc.issuedAt != 0, "Document does not exist");
        require(!doc.isFinalized, "Document already finalized");
        require(!doc.signatures[msg.sender], "Already signed");
        
        doc.signatures[msg.sender] = true;
        doc.signedBy = msg.sender;

        finalizeDocument(_documentId);
        
        emit DocumentSigned(_documentId, msg.sender);
    }

    function finalizeDocument(bytes32 _documentId) public onlySigner {
        Document storage doc = documents[_documentId];
        
        require(doc.issuedAt != 0, "Document does not exist");
        require(!doc.isFinalized, "Document already finalized");
        
        doc.isFinalized = true;
    }

    function getDocumentInfo(bytes32 _documentId) public view returns (
        string memory documentHash,
        address issuer,
        uint256 issuedAt,
        address signedBy,
        bool isFinalized
    ) {
        Document storage doc = documents[_documentId];
        require(doc.issuedAt != 0, "Document does not exist");
        
        return (
            doc.documentHash,
            doc.issuer,
            doc.issuedAt,
            doc.signedBy,
            doc.isFinalized
        );
    }

    function hasSignedDocument(bytes32 _documentId, address _signer) public view returns (bool) {
        return documents[_documentId].signatures[_signer];
    }

    function getDocumentCount() public view returns (uint) {
        return documentIds.length;
    }
}