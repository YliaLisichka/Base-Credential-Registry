// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

contract NovaCredentialRegistry {
    struct Credential {
        address studentWallet;
        address issuer;
        uint256 issueTimestamp;
        bool isValid;
        bytes32 courseHash;
    }

    address payable public immutable registryAdmin;
    string public registryDescriptor;
    uint256 public issuanceFeeWei; 
    uint256 public credentialCounter;
    uint256 public accumulatedFees;
    bool public isRegistryHalted;

    mapping(address => bool) public authorizedIssuers;
    mapping(uint256 => Credential) public credentials;

    event IssuerAdded(address indexed issuer);
    event CredentialCanceled(uint256 indexed credentialId);
    event TreasuryDeposited(address indexed funder, uint256 amount);
    event ReservesDrained(address indexed admin, uint256 amount);
    event FeesGathered(address indexed admin, uint256 amount);
    event RegistryHaltToggled(bool isHalted);
    event CredentialIssued(uint256 indexed credentialId, address indexed student, bytes32 courseHash);
    event IssuerRevoked(address indexed issuer);
    event DescriptorUpdated(string newDescriptor);

    modifier onlyAdmin() {
        require(msg.sender == registryAdmin, "NovaRegistry: Access denied");
        _;
    }

    modifier whenNotHalted() {
        require(!isRegistryHalted, "NovaRegistry: Registry is halted");
        _;
    }

    constructor() {
        registryAdmin = payable(msg.sender);
        registryDescriptor = "Nova Base Academic Registry v1";
        issuanceFeeWei = 10000000000000; // 0.00001 ETH за выпуск диплома
        isRegistryHalted = false;
        authorizedIssuers[msg.sender] = true; // Админ по умолчанию может выпускать сертификаты
    }

    // 1. addAuthorizedIssuer
    function addAuthorizedIssuer(address issuer) external onlyAdmin {
        require(!authorizedIssuers[issuer], "NovaRegistry: Already authorized");
        authorizedIssuers[issuer] = true;
        emit IssuerAdded(issuer);
    }

    // 2. cancelIssuedCredential
    function cancelIssuedCredential(uint256 credentialId) external {
        Credential storage c = credentials[credentialId];
        require(credentialId > 0 && credentialId <= credentialCounter, "NovaRegistry: Invalid ID");
        require(msg.sender == c.issuer || msg.sender == registryAdmin, "NovaRegistry: Unauthorized");
        require(c.isValid, "NovaRegistry: Already invalid");

        c.isValid = false;
        emit CredentialCanceled(credentialId);
    }

    // 3. depositPlatformTreasury
    function depositPlatformTreasury() external payable whenNotHalted {
        require(msg.value > 0, "NovaRegistry: Zero deposit");
        accumulatedFees += msg.value;
        emit TreasuryDeposited(msg.sender, msg.value);
    }

    // 4. drainPlatformReserves
    function drainPlatformReserves() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "NovaRegistry: Zero balance");

        accumulatedFees = 0;
        (bool sent, ) = registryAdmin.call{value: balance}("");
        require(sent, "NovaRegistry: Sweep failed");

        emit ReservesDrained(registryAdmin, balance);
    }

    // 5. gatherPlatformFees
    function gatherPlatformFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        require(amount > 0, "NovaRegistry: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = registryAdmin.call{value: amount}("");
        require(sent, "NovaRegistry: Harvest failed");

        emit FeesGathered(registryAdmin, amount);
    }

    // 6. haltCredentialRegistry
    function haltCredentialRegistry(bool isHalted) external onlyAdmin {
        isRegistryHalted = isHalted;
        emit RegistryHaltToggled(isHalted);
    }

    // 7. issueNewCredential
    function issueNewCredential(address student, bytes32 courseHash) external payable whenNotHalted returns (uint256) {
        require(authorizedIssuers[msg.sender], "NovaRegistry: Not an issuer");
        require(student != address(0), "NovaRegistry: Zero address student");
        require(msg.value >= issuanceFeeWei, "NovaRegistry: Insufficient fee");

        accumulatedFees += msg.value;

        credentialCounter++;
        credentials[credentialCounter] = Credential({
            studentWallet: student,
            issuer: msg.sender,
            issueTimestamp: block.timestamp,
            isValid: true,
            courseHash: courseHash
        });

        emit CredentialIssued(credentialCounter, student, courseHash);
        return credentialCounter;
    }

    // 8. revokeIssuerAccess
    function revokeIssuerAccess(address issuer) external onlyAdmin {
        require(authorizedIssuers[issuer], "NovaRegistry: Not an issuer");
        require(issuer != msg.sender, "NovaRegistry: Cannot revoke self");
        authorizedIssuers[issuer] = false;
        emit IssuerRevoked(issuer);
    }

    // 9. updateRegistryDescriptor
    function updateRegistryDescriptor(string calldata newDescriptor) external onlyAdmin {
        require(bytes(newDescriptor).length > 0, "NovaRegistry: Empty string");
        registryDescriptor = newDescriptor;
        emit DescriptorUpdated(newDescriptor);
    }
}