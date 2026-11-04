#!/usr/bin/env bash
# Fires one PO -> receipt -> invoice cycle on Sepolia against the deployed APLedger.
# Usage: KEY_FILE=~/.reactive/deployer.key ./script/demo.sh <poId> <invoiceId> <qty> <unitPrice6dp> [receivedQty] [invoicedUnitPrice]
set -euo pipefail
source "$(dirname "$0")/../deployments.env"
RPC=${SEPOLIA_RPC:-https://ethereum-sepolia-rpc.publicnode.com}
K=$(cat "${KEY_FILE:?set KEY_FILE}")
PO=$1 INV=$2 QTY=$3 PRICE=$4 RCV=${5:-$3} IPRICE=${6:-$4}
s(){ cast send "$LEDGER" "$@" --private-key "$K" --rpc-url "$RPC" --json | jq -r .transactionHash; }
echo "createPO   $(s 'createPO(uint256,address,uint256,uint256)' $PO $VENDOR $QTY $PRICE)"
echo "receive    $(s 'receiveGoods(uint256,uint256)' $PO $RCV)"
echo "invoice    $(s 'submitInvoice(uint256,uint256,uint256,uint256)' $PO $INV $QTY $IPRICE)"
echo "Now watch APEscrow ($ESCROW) on Sepolia for InvoicePaid / InvoiceHeld / DuplicateBlocked."
