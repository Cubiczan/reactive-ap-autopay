// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";
import { APMatch } from "./APMatch.sol";

/// @title APMatchReactive: the always-on three-way-match control, running on Reactive Network
/// @notice Subscribes to APLedger events on the origin chain, keeps PO/receipt state, and for each
/// invoice requests a callback to APEscrow on the destination chain with PAY or a HOLD/BLOCK reason.
contract APMatchReactive is AbstractReactive {
    using APMatch for APMatch.PO;

    uint256 public constant PO_CREATED_TOPIC = uint256(keccak256("POCreated(uint256,address,uint256,uint256)"));
    uint256 public constant GOODS_RECEIVED_TOPIC = uint256(keccak256("GoodsReceived(uint256,uint256)"));
    uint256 public constant INVOICE_SUBMITTED_TOPIC = uint256(keccak256("InvoiceSubmitted(uint256,uint256,uint256,uint256)"));
    uint64 public constant CALLBACK_GAS_LIMIT = 1_000_000;

    event InvoiceDecided(uint256 indexed poId, uint256 indexed invoiceId, APMatch.Decision decision, uint256 amount);
    event RecipientSet(address recipient);

    error NotOwner();
    error WrongSource();

    address public immutable owner;
    uint256 public immutable originChainId;
    address public immutable ledger;
    uint256 public immutable destinationChainId;
    uint256 public immutable toleranceBps;
    address public escrow;

    mapping(uint256 => APMatch.PO) public pos;
    mapping(uint256 => bool) public invoiceSeen;

    constructor(uint256 originChainId_, address ledger_, uint256 destinationChainId_, uint256 toleranceBps_) payable {
        owner = msg.sender;
        originChainId = originChainId_;
        ledger = ledger_;
        destinationChainId = destinationChainId_;
        toleranceBps = toleranceBps_;
        _sub(PO_CREATED_TOPIC);
        _sub(GOODS_RECEIVED_TOPIC);
        _sub(INVOICE_SUBMITTED_TOPIC);
    }

    function _sub(uint256 topic0) internal {
        SYSTEM.subscribe(originChainId, ledger, topic0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    /// @notice Escrow is deployed after this contract (it needs our address), so it's set once here.
    function setEscrow(address escrow_) external {
        if (msg.sender != owner) revert NotOwner();
        escrow = escrow_;
        emit RecipientSet(escrow_);
    }

    function coverDebt() external { _coverDebt(); }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log_) external onlySystem {
        if (log_.chainId != originChainId || log_.contractAddress != ledger) revert WrongSource();
        uint256 poId = log_.topic1;

        if (log_.topic0 == PO_CREATED_TOPIC) {
            (uint256 qty, uint256 unitPrice) = abi.decode(log_.data, (uint256, uint256));
            pos[poId] = APMatch.PO(address(uint160(log_.topic2)), qty, unitPrice, 0, 0, true);
        } else if (log_.topic0 == GOODS_RECEIVED_TOPIC) {
            uint256 qty = abi.decode(log_.data, (uint256));
            pos[poId].receivedQty += qty;
        } else if (log_.topic0 == INVOICE_SUBMITTED_TOPIC) {
            uint256 invoiceId = log_.topic2;
            (uint256 qty, uint256 unitPrice) = abi.decode(log_.data, (uint256, uint256));
            APMatch.PO storage po = pos[poId];
            APMatch.Decision d = APMatch.evaluate(po, invoiceSeen[invoiceId], qty, unitPrice, toleranceBps);
            uint256 amount = qty * unitPrice;
            if (d != APMatch.Decision.BLOCK_DUPLICATE) invoiceSeen[invoiceId] = true;
            if (d == APMatch.Decision.PAY) po.invoicedQty += qty;
            emit InvoiceDecided(poId, invoiceId, d, amount);

            bytes memory payload = abi.encodeWithSignature(
                "settle(address,uint256,uint256,address,uint256,uint8)",
                address(0), poId, invoiceId, po.vendor, amount, uint8(d)
            );
            SYSTEM.requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destinationChainId,
                recipient: escrow,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            }));
        }
    }
}
