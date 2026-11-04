// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";

interface IERC20Min {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address a) external view returns (uint256);
}

/// @title APEscrow: destination-chain payables account that only pays on a matched invoice
/// @notice Accepts calls only from the Reactive callback proxy AND only on behalf of the authorized
/// APMatchReactive contract. Holds are parked for a human (the CFO) to release or reject.
contract APEscrow is AbstractCallback {
    enum Status { NONE, PAID, HELD, BLOCKED, RELEASED, REJECTED }

    struct Invoice { uint256 poId; address vendor; uint256 amount; uint8 reason; Status status; }

    event InvoicePaid(uint256 indexed poId, uint256 indexed invoiceId, address indexed vendor, uint256 amount);
    event InvoiceHeld(uint256 indexed poId, uint256 indexed invoiceId, uint8 reason, uint256 amount);
    event DuplicateBlocked(uint256 indexed poId, uint256 indexed invoiceId, uint256 amount);
    event HoldResolved(uint256 indexed invoiceId, bool released);

    error NotOwner();
    error NotHeld();

    uint8 internal constant PAY = 0;
    uint8 internal constant BLOCK_DUPLICATE = 3;
    uint8 public constant HOLD_INSUFFICIENT_FUNDS = 9;

    address public immutable owner;
    IERC20Min public immutable token;
    mapping(uint256 => Invoice) public invoices;

    constructor(IPayable callbackProxy_, address reactive_, IERC20Min token_)
        payable AbstractCallback(callbackProxy_, reactive_)
    {
        owner = msg.sender;
        token = token_;
    }

    function settle(address rvm, uint256 poId, uint256 invoiceId, address vendor, uint256 amount, uint8 decision)
        external onlyServiceProvider onlyCallbackSender(rvm)
    {
        if (decision == BLOCK_DUPLICATE) {
            emit DuplicateBlocked(poId, invoiceId, amount);
            if (invoices[invoiceId].status == Status.NONE)
                invoices[invoiceId] = Invoice(poId, vendor, amount, decision, Status.BLOCKED);
            return;
        }
        if (decision == PAY && token.balanceOf(address(this)) >= amount) {
            invoices[invoiceId] = Invoice(poId, vendor, amount, decision, Status.PAID);
            token.transfer(vendor, amount);
            emit InvoicePaid(poId, invoiceId, vendor, amount);
            return;
        }
        uint8 reason = decision == PAY ? HOLD_INSUFFICIENT_FUNDS : decision;
        invoices[invoiceId] = Invoice(poId, vendor, amount, reason, Status.HELD);
        emit InvoiceHeld(poId, invoiceId, reason, amount);
    }

    /// @notice Human override for held invoices (e.g. approved price change). Not available for duplicates.
    function resolveHold(uint256 invoiceId, bool release) external {
        if (msg.sender != owner) revert NotOwner();
        Invoice storage inv = invoices[invoiceId];
        if (inv.status != Status.HELD) revert NotHeld();
        inv.status = release ? Status.RELEASED : Status.REJECTED;
        if (release) token.transfer(inv.vendor, inv.amount);
        emit HoldResolved(invoiceId, release);
    }

    function coverDebt() external { _coverDebt(); }
}
