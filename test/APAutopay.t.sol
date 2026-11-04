// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { APMatchReactive } from "../src/APMatchReactive.sol";
import { APEscrow, IERC20Min } from "../src/APEscrow.sol";
import { APLedger } from "../src/APLedger.sol";
import { APMatch } from "../src/APMatch.sol";
import { MockUSD } from "../src/MockUSD.sol";

/// Stand-in for Reactive's system contract: records subscriptions and callback requests.
contract MockSystem {
    uint256 public subs;
    ISystemContract.CallbackConfiguration_V_1_0[] internal reqs;
    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external { subs++; }
    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external {}
    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory c) external { reqs.push(c); }
    function count() external view returns (uint256) { return reqs.length; }
    function last() external view returns (ISystemContract.CallbackConfiguration_V_1_0 memory) { return reqs[reqs.length - 1]; }
    function debt(address) external pure returns (uint256) { return 0; }
}

contract APAutopayTest is Test {
    address constant SYS = 0x8888888888888888888888888888888888888888;
    address constant PROXY = address(0xCA11);
    uint256 constant ORIGIN = 11155111;
    address constant LEDGER = address(0x1ED6E2);
    address vendor = address(0xBEEF);

    MockSystem sys;
    APMatchReactive rc;
    APEscrow escrow;
    MockUSD usd;

    function setUp() public {
        vm.etch(SYS, address(new MockSystem()).code);
        sys = MockSystem(SYS);
        rc = new APMatchReactive(ORIGIN, LEDGER, ORIGIN, 200); // 2% price tolerance
        usd = new MockUSD();
        escrow = new APEscrow(IPayable(payable(PROXY)), address(rc), IERC20Min(address(usd)));
        rc.setEscrow(address(escrow));
        usd.mint(address(escrow), 1_000_000e6);
    }

    function _log(uint256 t0, uint256 t1, uint256 t2, bytes memory data) internal pure returns (IReactive.LogRecord memory l) {
        l.chainId = ORIGIN; l.contractAddress = LEDGER; l.topic0 = t0; l.topic1 = t1; l.topic2 = t2; l.data = data;
    }

    function _po(uint256 id, uint256 qty, uint256 price) internal {
        IReactive.LogRecord memory l = _log(rc.PO_CREATED_TOPIC(), id, uint256(uint160(vendor)), abi.encode(qty, price)); vm.prank(SYS); rc.react(l);
    }
    function _grn(uint256 id, uint256 qty) internal {
        IReactive.LogRecord memory l = _log(rc.GOODS_RECEIVED_TOPIC(), id, 0, abi.encode(qty)); vm.prank(SYS); rc.react(l);
    }
    /// Submits an invoice, then delivers the requested callback the way the proxy would (sender injected).
    function _inv(uint256 id, uint256 invId, uint256 qty, uint256 price) internal {
        IReactive.LogRecord memory l = _log(rc.INVOICE_SUBMITTED_TOPIC(), id, invId, abi.encode(qty, price)); vm.prank(SYS); rc.react(l);
        ISystemContract.CallbackConfiguration_V_1_0 memory c = sys.last();
        assertEq(c.recipient, address(escrow));
        assertEq(c.chainId, ORIGIN);
        bytes memory p = c.payload;
        address rcAddr = address(rc);
        assembly { mstore(add(p, 36), rcAddr) } // proxy overwrites first arg with requester
        vm.prank(PROXY);
        (bool ok,) = address(escrow).call(p);
        assertTrue(ok);
    }

    function _status(uint256 invId) internal view returns (APEscrow.Status s, uint8 reason) {
        (,,, reason, s) = escrow.invoices(invId);
    }

    function test_subscribesToThreeEvents() public view { assertEq(sys.subs(), 3); }

    function test_matchedInvoicePaysVendor() public {
        _po(1, 100, 25e6); _grn(1, 100); _inv(1, 9001, 100, 25e6);
        assertEq(usd.balanceOf(vendor), 2_500e6);
        (APEscrow.Status s,) = _status(9001); assertEq(uint8(s), uint8(APEscrow.Status.PAID));
    }

    function test_priceWithinToleranceStillPays() public {
        _po(1, 10, 100e6); _grn(1, 10); _inv(1, 1, 10, 102e6);
        assertEq(usd.balanceOf(vendor), 1_020e6);
    }

    function test_priceOverToleranceHeld() public {
        _po(1, 10, 100e6); _grn(1, 10); _inv(1, 1, 10, 103e6);
        assertEq(usd.balanceOf(vendor), 0);
        (APEscrow.Status s, uint8 r) = _status(1);
        assertEq(uint8(s), uint8(APEscrow.Status.HELD)); assertEq(r, uint8(APMatch.Decision.HOLD_PRICE));
    }

    function test_invoiceBeforeReceiptHeld() public {
        _po(1, 10, 100e6); _grn(1, 4); _inv(1, 1, 10, 100e6);
        (, uint8 r) = _status(1); assertEq(r, uint8(APMatch.Decision.HOLD_QTY));
    }

    function test_partialDeliveriesAndSplitInvoices() public {
        _po(1, 10, 100e6); _grn(1, 4); _inv(1, 1, 4, 100e6);
        _grn(1, 6); _inv(1, 2, 6, 100e6);
        assertEq(usd.balanceOf(vendor), 1_000e6);
        _inv(1, 3, 1, 100e6); // over-billing beyond received
        (, uint8 r) = _status(3); assertEq(r, uint8(APMatch.Decision.HOLD_QTY));
    }

    function test_duplicateInvoiceBlocked() public {
        _po(1, 10, 100e6); _grn(1, 20); _inv(1, 7, 10, 100e6); _inv(1, 7, 10, 100e6);
        assertEq(usd.balanceOf(vendor), 1_000e6); // paid once only
        (APEscrow.Status s,) = _status(7); assertEq(uint8(s), uint8(APEscrow.Status.PAID));
    }

    function test_unknownPOHeld() public {
        _inv(42, 1, 1, 1e6);
        (, uint8 r) = _status(1); assertEq(r, uint8(APMatch.Decision.HOLD_NO_PO));
    }

    function test_insufficientEscrowFundsHeld() public {
        _po(1, 1, 2_000_000e6); _grn(1, 1); _inv(1, 1, 1, 2_000_000e6);
        (, uint8 r) = _status(1); assertEq(r, escrow.HOLD_INSUFFICIENT_FUNDS());
    }

    function test_cfoCanReleaseHold() public {
        _po(1, 10, 100e6); _grn(1, 10); _inv(1, 1, 10, 110e6);
        escrow.resolveHold(1, true);
        assertEq(usd.balanceOf(vendor), 1_100e6);
        vm.expectRevert(APEscrow.NotHeld.selector); escrow.resolveHold(1, true);
    }

    function test_reactRejectsNonSystem() public {
        IReactive.LogRecord memory l = _log(rc.PO_CREATED_TOPIC(), 1, 0, abi.encode(uint256(1), uint256(1)));
        vm.expectRevert();
        rc.react(l);
    }

    function test_reactRejectsOtherSource() public {
        IReactive.LogRecord memory l = _log(rc.PO_CREATED_TOPIC(), 1, 0, abi.encode(uint256(1), uint256(1)));
        l.contractAddress = address(0xBAD);
        vm.prank(SYS); vm.expectRevert(APMatchReactive.WrongSource.selector); rc.react(l);
    }

    function test_escrowRejectsDirectCall() public {
        vm.expectRevert();
        escrow.settle(address(rc), 1, 1, vendor, 1, 0);
    }

    function test_escrowRejectsForeignReactiveSender() public {
        vm.prank(PROXY); vm.expectRevert();
        escrow.settle(address(0xEE), 1, 1, vendor, 1, 0);
    }

    function test_ledgerAccess() public {
        APLedger l = new APLedger();
        l.createPO(1, vendor, 1, 1);
        vm.prank(vendor); l.submitInvoice(1, 1, 1, 1);
        vm.prank(address(0xD00D)); vm.expectRevert(APLedger.NotAuthorized.selector); l.submitInvoice(1, 2, 1, 1);
        vm.prank(vendor); vm.expectRevert(APLedger.NotAuthorized.selector); l.receiveGoods(1, 1);
    }

    function testFuzz_neverPaysAboveReceived(uint8 rcv, uint8 inv) public {
        vm.assume(inv > 0);
        _po(1, 1000, 1e6); _grn(1, rcv); _inv(1, 1, inv, 1e6);
        assertLe(usd.balanceOf(vendor), uint256(rcv) * 1e6);
    }
}
