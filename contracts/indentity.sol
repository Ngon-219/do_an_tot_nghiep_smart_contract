// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./issuance_of_documents.sol";

interface IFactoryContract {
    function get_issuance_contract_address() external view returns (address);
}

contract IdentityContract {
    mapping(address => uint256) public userIds;
    uint256 public nextId = 1;
    IFactoryContract public factory;

    constructor(address _factory) {
        factory = IFactoryContract(_factory);
    }

    function register(address[] memory _users, address _signer) external {  
        address issuanceAddress = factory.get_issuance_contract_address(); 
        IssuanceOfDocument doc = IssuanceOfDocument(issuanceAddress);
        require(doc.isSigner(_signer), "Signer is not valid");
        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            require(userIds[user] == 0, "User already registered");
            userIds[user] = nextId;
            nextId++;
        }
    }

    function getUserId(address user) external view returns (uint256) {
        return userIds[user];
    }
}
