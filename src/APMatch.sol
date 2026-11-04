// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title APMatch: three-way match rules (PO vs goods receipt vs invoice)
/// @notice Pure decision logic shared by the reactive contract and the tests.
library APMatch {
    enum Decision { PAY, HOLD_PRICE, HOLD_QTY, BLOCK_DUPLICATE, HOLD_NO_PO }

    struct PO {
        address vendor;
        uint256 orderedQty;
        uint256 unitPrice;   // in settlement-token base units
        uint256 receivedQty;
        uint256 invoicedQty; // qty already approved for payment
        bool exists;
    }

    /// @param toleranceBps allowed unit-price overage, in basis points
    function evaluate(
        PO memory po,
        bool duplicate,
        uint256 invQty,
        uint256 invUnitPrice,
        uint256 toleranceBps
    ) internal pure returns (Decision) {
        if (duplicate) return Decision.BLOCK_DUPLICATE;
        if (!po.exists) return Decision.HOLD_NO_PO;
        if (invUnitPrice * 10_000 > po.unitPrice * (10_000 + toleranceBps)) return Decision.HOLD_PRICE;
        if (po.invoicedQty + invQty > po.receivedQty) return Decision.HOLD_QTY;
        return Decision.PAY;
    }
}
