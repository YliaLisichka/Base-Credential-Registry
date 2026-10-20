// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface INovaCredentialRegistry {
    function issueNewCredential(address student, bytes32 courseHash) external payable returns (uint256);
}
