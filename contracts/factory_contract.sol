// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./issuance_of_documents.sol";
import "./indentity.sol";
import "./student_score.sol";
import "./voting_contract.sol";

contract FactoryContract {
    IssuanceOfDocument public issuance_document;
    IdentityContract public identity;

    constructor () {
        issuance_document = new IssuanceOfDocument();
        identity = new IdentityContract(address(this));
    }

    function get_issuance_contract_address() external view returns (address) {
        return address(issuance_document);
    }

    function get_identity_contract_address() external view returns (address) {
        return address(identity);
    }

    function addSigner(address _signer) external {
        issuance_document.addSigner(_signer);
    }

    function registerUsers(address[] memory _users, address _signer) external {
        identity.register(_users, _signer);
    }

    function getUserId(address user) external view returns (uint256) {
        return identity.getUserId(user);
    }

    function isSigner(address _signer) external view returns (bool) {
        return issuance_document.isSigner(_signer);
    }

    function deployStudentScore() external returns (address) {
        StudentScore studentScore = new StudentScore(address(this));
        return address(studentScore);
    }

    function deployVotingContract() external returns (address) {
        VotingContract votingContract = new VotingContract(address(this));
        return address(votingContract);
    }
}