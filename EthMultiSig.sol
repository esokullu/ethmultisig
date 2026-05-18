// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  EthMultiSig — a minimal, zero-dependency Ethereum multisig wallet.
/// @notice ~120 lines, no imports, no proxies, no delegatecall, no modules.
///         You can audit the entire wallet in one sitting.
/// @dev    Security is provided by transparency and simplicity, not complexity.
contract EthMultiSig {
    // ---------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------

    address[] public owners;
    uint256   public threshold;
    mapping(address => bool) public isOwner;

    struct Transaction {
        address to;
        uint256 value;
        bytes   data;
        bool    executed;
        uint256 confirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmed;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event Deposit(address indexed sender, uint256 amount);
    event Submit (uint256 indexed txId, address indexed owner, address to, uint256 value, bytes data);
    event Confirm(uint256 indexed txId, address indexed owner);
    event Revoke (uint256 indexed txId, address indexed owner);
    event Execute(uint256 indexed txId);

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier exists(uint256 txId) {
        require(txId < transactions.length, "no such tx");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "executed");
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @param _owners    Distinct, non-zero owner addresses.
    /// @param _threshold Confirmations required to execute (1..owners.length).
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "bad threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0), "zero owner");
            require(!isOwner[o],     "duplicate");
            isOwner[o] = true;
            owners.push(o);
        }
        threshold = _threshold;
    }

    // ---------------------------------------------------------------
    // Receive
    // ---------------------------------------------------------------

    receive() external payable { emit Deposit(msg.sender, msg.value); }

    // ---------------------------------------------------------------
    // Core API
    // ---------------------------------------------------------------

    /// @notice Propose a transaction. The proposer auto-confirms.
    function submit(address to, uint256 value, bytes calldata data)
        external onlyOwner returns (uint256 txId)
    {
        txId = transactions.length;
        transactions.push(Transaction({
            to: to, value: value, data: data,
            executed: false, confirmations: 0
        }));
        emit Submit(txId, msg.sender, to, value, data);
        _confirm(txId);
    }

    /// @notice Confirm a proposed transaction.
    function confirm(uint256 txId)
        external onlyOwner exists(txId) notExecuted(txId)
    {
        _confirm(txId);
    }

    function _confirm(uint256 txId) internal {
        require(!confirmed[txId][msg.sender], "already confirmed");
        confirmed[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;
        emit Confirm(txId, msg.sender);
    }

    /// @notice Revoke your prior confirmation (only before execution).
    function revoke(uint256 txId)
        external onlyOwner exists(txId) notExecuted(txId)
    {
        require(confirmed[txId][msg.sender], "not confirmed");
        confirmed[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;
        emit Revoke(txId, msg.sender);
    }

    /// @notice Execute once enough owners have confirmed.
    function execute(uint256 txId)
        external onlyOwner exists(txId) notExecuted(txId)
    {
        Transaction storage t = transactions[txId];
        require(t.confirmations >= threshold, "need more confirmations");
        t.executed = true;
        (bool ok, bytes memory ret) = t.to.call{value: t.value}(t.data);
        require(ok, _revertReason(ret));
        emit Execute(txId);
    }

    // ---------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------

    function getOwners() external view returns (address[] memory) { return owners; }
    function txCount()    external view returns (uint256)         { return transactions.length; }

    function getTransaction(uint256 txId)
        external view exists(txId)
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmations)
    {
        Transaction storage t = transactions[txId];
        return (t.to, t.value, t.data, t.executed, t.confirmations);
    }

    // ---------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------

    function _revertReason(bytes memory ret) internal pure returns (string memory) {
        if (ret.length < 68) return "call failed";
        assembly { ret := add(ret, 0x04) }
        return abi.decode(ret, (string));
    }
}
