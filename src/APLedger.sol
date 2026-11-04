// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title APLedger: origin-chain record of purchase orders, goods receipts and vendor invoices
/// @notice Only emits events. The matching happens on Reactive Network; payment happens in APEscrow.
contract APLedger {
    event POCreated(uint256 indexed poId, address indexed vendor, uint256 qty, uint256 unitPrice);
    event GoodsReceived(uint256 indexed poId, uint256 qty);
    event InvoiceSubmitted(uint256 indexed poId, uint256 indexed invoiceId, uint256 qty, uint256 unitPrice);

    error NotAuthorized();
    error POExists();
    error UnknownPO();

    address public immutable owner; // the buyer's AP / procurement function
    mapping(uint256 => address) public vendorOf;

    constructor() { owner = msg.sender; }

    function createPO(uint256 poId, address vendor, uint256 qty, uint256 unitPrice) external {
        if (msg.sender != owner) revert NotAuthorized();
        if (vendorOf[poId] != address(0)) revert POExists();
        vendorOf[poId] = vendor;
        emit POCreated(poId, vendor, qty, unitPrice);
    }

    /// @notice Receiving dock confirms delivered quantity (can be called several times for partial deliveries).
    function receiveGoods(uint256 poId, uint256 qty) external {
        if (msg.sender != owner) revert NotAuthorized();
        if (vendorOf[poId] == address(0)) revert UnknownPO();
        emit GoodsReceived(poId, qty);
    }

    /// @notice Vendor (or AP keying on the vendor's behalf) submits an invoice. Deliberately NOT validated here:
    /// duplicates, wrong prices and unknown POs must reach the control so it can stop them.
    function submitInvoice(uint256 poId, uint256 invoiceId, uint256 qty, uint256 unitPrice) external {
        if (msg.sender != owner && msg.sender != vendorOf[poId]) revert NotAuthorized();
        emit InvoiceSubmitted(poId, invoiceId, qty, unitPrice);
    }
}
