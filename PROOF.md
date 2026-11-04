# PROOF: on-chain runs (testnet)

Everything below happened on public testnets on **Nov 4, 2026**. Origin and destination are Ethereum Sepolia (11155111). The reactive contract runs on Reactive Lasna (5318007). The settlement token is a testnet mock with no value.

## Contracts

| Contract | Chain | Address |
|---|---|---|
| APLedger (origin events) | Sepolia | [0xC4a2659301724cEB4546815F5e5bE65783D58279](https://sepolia.etherscan.io/address/0xC4a2659301724cEB4546815F5e5bE65783D58279) |
| APMatchReactive (the control) | Lasna | [0xb27ADae268C8322A84e06574B49C2F845Cc112e4](https://lasna.reactscan.net/address/0xb27ADae268C8322A84e06574B49C2F845Cc112e4) |
| APEscrow (callback / payables) | Sepolia | [0x7c143047E7DddE6752ba26d457321A7489FA5C16](https://sepolia.etherscan.io/address/0x7c143047E7DddE6752ba26d457321A7489FA5C16) |
| MockUSD (mUSD, 6 dp) | Sepolia | [0x9881b1827A05cB60B5Db3Ba139c313bDeD20342c](https://sepolia.etherscan.io/address/0x9881b1827A05cB60B5Db3Ba139c313bDeD20342c) |

Callback proxy (Sepolia, per Reactive docs): `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`. Vendor (demo payee): `0x...bEEF`.

## Setup transactions

| Step | Tx |
|---|---|
| Deploy MockUSD (Sepolia) | [0xadfdc784…](https://sepolia.etherscan.io/tx/0xadfdc784ac0dff17e2c7f22d337112c8a5c116dc16af40f61f01d5105fe33862) |
| Deploy APLedger (Sepolia) | [0x35dad17c…](https://sepolia.etherscan.io/tx/0x35dad17c47d31665c9f676252c5c1af23d4b87192d71e585f37a6b1c5dc5ee27) |
| Deploy APMatchReactive + 3 subscriptions (Lasna) | [0x376f2d4c…](https://lasna.reactscan.net/tx/0x376f2d4c86eacd2d55e613cad617449fe865c6492cf6e800d33d7e9abebab256) |
| Deploy APEscrow (Sepolia) | [0x4c52cd10…](https://sepolia.etherscan.io/tx/0x4c52cd10fcae00398a92982047bcb69f5502b9c4c450e045988fe8946fb03760) |
| setEscrow (Lasna) | [0x8bf7dffd…](https://lasna.reactscan.net/tx/0x8bf7dffd28b33ed54a476e8425e86725b9537dfdabad5e77cea82a5ab16debc2) |
| Fund escrow with 100,000 mUSD | [0x2046b053…](https://sepolia.etherscan.io/tx/0x2046b053dac30433f6ff1f370ba092aa99c595ed1c3563b3884ad5334c774359) |

## Full loops: origin event → reactive tx → callback

| Scenario | Origin tx (Sepolia) | Reactive tx (Lasna) | Callback tx (Sepolia) | Result |
|---|---|---|---|---|
| PO 1001: 100 @ 25.00, received 100, invoice 5001 matches | [0xde651e3c…](https://sepolia.etherscan.io/tx/0xde651e3c1e89d62141235489e9aa1aba47b2e20d249ee4292332d6b27ca9c295) | [0x0ec867ba…](https://lasna.reactscan.net/tx/0x0ec867ba1e186ce0968e26bc5be7e83fe04e14983706afa21018e1e4e7b03a86) | [0xab6de6ce…](https://sepolia.etherscan.io/tx/0xab6de6ced4dc0efc6dd414ef047cec2fac214a133bd67c808b2b6ea863908e57) | **InvoicePaid**: 2,500 mUSD to vendor |
| Same invoice 5001 resubmitted | [0xa385225c…](https://sepolia.etherscan.io/tx/0xa385225cf38744c82aece3141da0de2e8a36e51ef7d0c243c5be0bfb27eadce9) | [0xa3a38a31…](https://lasna.reactscan.net/tx/0xa3a38a31094f7f96a84b0c27583171543261a8f0c2c7c2e111130cc8457e0a9c) | [0xf389a4e8…](https://sepolia.etherscan.io/tx/0xf389a4e8af6b12cad2ddfe10e041e6c0cf2368d1180e962ddc4dd31e5220af37) | **DuplicateBlocked**, nothing paid |
| PO 1004: 50 @ 40.00, invoice 5005 bills 44.00 (+10%, tolerance 2%) | [0x36e8d8b8…](https://sepolia.etherscan.io/tx/0x36e8d8b8e622fb5c7ee84076d35f5e0e8af5314af2cefdb80aea33722a1636a3) | [0x84ed66ff…](https://lasna.reactscan.net/tx/0x84ed66ffb4e1052149098682ab9b9db75228d420d962c85a5748e7d559464962) | [0xc0a3cae9…](https://sepolia.etherscan.io/tx/0xc0a3cae9c8b46cdde745bdff7517b18304842279f1b5447923cab0093164c882) | **InvoiceHeld**, reason 1 = HOLD_PRICE |
| PO 1003: 200 ordered, 120 received, invoice 5003 bills 200 | [0x60eafb6f…](https://sepolia.etherscan.io/tx/0x60eafb6f445396e1b8425cd5bcf22a8caeb6107761a1d4699e7e1d4c435897b9) | [0x845c493f…](https://lasna.reactscan.net/tx/0x845c493f7c8d385090d3f2af05e27505c6588c6c85073dc28fefd30ec9f0cee1) | [0x02be51b7…](https://sepolia.etherscan.io/tx/0x02be51b79c2fb6b730496762983846d112bcfa7292c89052bb0cf893790af14e) | **InvoiceHeld**, reason 2 = HOLD_QTY |
| Invoice 5004 against non-existent PO 9999 | [0xaca0692b…](https://sepolia.etherscan.io/tx/0xaca0692b9d16383a354e8b01fa2d3a84de59a52de04940a90a3d843778704d48) | [0x0896f38c…](https://lasna.reactscan.net/tx/0x0896f38c39f8f745695fc428beadcce1da5f4182a9fef4c00cbabbecc97a2921) | [0x7acc457a…](https://sepolia.etherscan.io/tx/0x7acc457ae78f5c384e1dbb892dc590ccd13dd1be8f8a7c33833ff8f360db253e) | **InvoiceHeld**, reason 4 = HOLD_NO_PO |
| Invoice 5002 against PO 1002 (PO creation tx failed at the RPC, so the PO never existed) | [0x9a241e5f…](https://sepolia.etherscan.io/tx/0x9a241e5f9b217267c87508c906ddfe474d7a40072962c35d8d0101b90b7f9c29) | [0x2699d0c5…](https://lasna.reactscan.net/tx/0x2699d0c5f1d94a7187b209739de9d09da9b85becd41fdb545d0d3c8a65006a8d) | [0x87fb7ab6…](https://sepolia.etherscan.io/tx/0x87fb7ab6b1a74d7823af488a83f0f5f02478a98b9c30ae00c2359eb1620aba29) | **InvoiceHeld**, reason 4 = HOLD_NO_PO (unplanned, but correct) |

PO and receipt events also flowed through Lasna and updated the control's state. For example, PO 1001 is [0x728aab99…](https://sepolia.etherscan.io/tx/0x728aab99c418660dc75220bc588b6b0a6c752eec60a50e6761bf1d54376b7bf4) and GRN 1001 is [0x637b6b34…](https://sepolia.etherscan.io/tx/0x637b6b349d77c0c98adc3fd550309b41ec562dbfd04ef3e5fabbb81c60f86671). PO 1004 is [0x75c2cea9…](https://sepolia.etherscan.io/tx/0x75c2cea99af3c6cbbe7254a6d30f10a8195ccb7bb9791e2fc4fcb57eba4c63b5) and GRN 1004 is [0xd2593aa0…](https://sepolia.etherscan.io/tx/0xd2593aa0b06203acd301a115f9b39bad7b7e9c353f29c6d57c1420670e045c37). PO 1003 is [0x3b8305bc…](https://sepolia.etherscan.io/tx/0x3b8305bcfe22543dcfb2d5a2bf87beb1a8fae8b4c395b1a1089bdfebbfd6b30b) and GRN 1003 is [0x00452621…](https://sepolia.etherscan.io/tx/0x0045262162a2b85554154d06ac81bfc7b497f7a09da63a5b993cb6b296dda126).

## Human override

| Step | Tx | Result |
|---|---|---|
| CFO releases price hold on invoice 5005 | [0x608dde60…](https://sepolia.etherscan.io/tx/0x608dde6084fcf68578e0a8934c065a9403f0f6dea97c7f64a1e462934dceb738) | 2,200 mUSD paid. Vendor total is 4,700 mUSD |

## Funding (free testnet faucets)
- Sepolia PoW faucet (pk910) claims: [0xa747b180…](https://sepolia.etherscan.io/tx/0xa747b180d5ca2a8b7d7b4ad3513740924a06c22b381c575ba7fe933526f3d101) and [0xd010c40b…](https://sepolia.etherscan.io/tx/0xd010c40b0daf6f72a9bfc7537a7de5edf8ef5fb50c6ef518cd580e53032cdceb)
- lREACT bought with 0.1 SepETH at the Reactive faucet contract: [0x0fd0a971…](https://sepolia.etherscan.io/tx/0x0fd0a97141132e8f6eb36a3aef711883553ecff008a340511c974cb907fb0db5)
