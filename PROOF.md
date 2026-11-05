# PROOF: on-chain runs (testnet)

Everything below happened on public testnets on **Nov 5, 2026**. Origin and destination are Ethereum Sepolia (11155111). The reactive contract runs on Reactive Lasna (5318007). The settlement token is a testnet mock with no value.

## Contracts

| Contract | Chain | Address |
|---|---|---|
| APLedger (origin events) | Sepolia | [0x64F97864597D323B0Ae7D8fdbd27fC32365547dC](https://sepolia.etherscan.io/address/0x64F97864597D323B0Ae7D8fdbd27fC32365547dC) |
| APMatchReactive (the control) | Lasna | [0xC4a2659301724cEB4546815F5e5bE65783D58279](https://lasna.reactscan.net/address/0xC4a2659301724cEB4546815F5e5bE65783D58279) |
| APEscrow (callback / payables) | Sepolia | [0x6D15d5108e5E8B7480B520D500e4287Fda761cF9](https://sepolia.etherscan.io/address/0x6D15d5108e5E8B7480B520D500e4287Fda761cF9) |
| MockUSD (mUSD, 6 dp) | Sepolia | [0x53C286Dc509A80Ca46BB9886d75e3d4cDe5418a8](https://sepolia.etherscan.io/address/0x53C286Dc509A80Ca46BB9886d75e3d4cDe5418a8) |

Callback proxy (Sepolia, per Reactive docs): `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`. Vendor (demo payee): `0x...bEEF`.

## Setup transactions

| Step | Tx |
|---|---|
| Deploy MockUSD (Sepolia) | [0x7bb82c3f…](https://sepolia.etherscan.io/tx/0x7bb82c3f22ccc62a1479cf878c24f5e5125e26282166bf607dbbf88b4295e7b7) |
| Deploy APLedger (Sepolia) | [0x9cf51264…](https://sepolia.etherscan.io/tx/0x9cf51264d0da1e7ce2a0a815e01c63c133260eaa5b65dac33c5b27adcd741138) |
| Deploy APMatchReactive + 3 subscriptions (Lasna) | [0xe99103d4…](https://lasna.reactscan.net/tx/0xe99103d45e6bc093f28183b08ccc9128635a341687ebf9f68cb389383d2a2e6c) |
| Deploy APEscrow (Sepolia) | [0x94847081…](https://sepolia.etherscan.io/tx/0x948470818f864cbaaa85f7219852b46f64a26f88b32d5e0c37ca3127536ed36d) |
| setEscrow (Lasna) | [0x49c8a74b…](https://lasna.reactscan.net/tx/0x49c8a74b6cd596b038470e298324b3b05212c6a05a3ae08dbc243ac48a9efa9f) |
| Mint 100,000 mUSD | [0x0e55781d…](https://sepolia.etherscan.io/tx/0x0e55781d70f9240084fe734d986fd2d9ad749b5d391cd214fa91e3a04a3279fa) |
| Fund escrow with 100,000 mUSD | [0x301f0481…](https://sepolia.etherscan.io/tx/0x301f04812374d35a02b48b9ca857fceca8582ebf8f5fb3ff5015c52df214fd95) |

## Full loops: origin event → reactive tx → callback

| Scenario | Origin tx (Sepolia) | Reactive tx (Lasna) | Callback tx (Sepolia) | Result |
|---|---|---|---|---|
| PO 3001: 100 @ 25.00, received 100, invoice 7001 matches | [0x9eaf81fc…](https://sepolia.etherscan.io/tx/0x9eaf81fcb18e5340a03c8ed69a287c8c7460182bb89e5956ac3c4d5b95dc7e2c) | [0x921e7ed4…](https://lasna.reactscan.net/tx/0x921e7ed476b53f8e4fc08d8c553d18842e6c061bb5a3cc4f80ab1f351279a0bf) | [0x05e093d7…](https://sepolia.etherscan.io/tx/0x05e093d74ba9b5bc7a2712fcfc2e302f1bc0acc1e8a0b3d72c40b17ad7796505) | **InvoicePaid**: 2,500 mUSD to vendor |
| Same invoice 7001 resubmitted | [0xc90249f0…](https://sepolia.etherscan.io/tx/0xc90249f0148ebbe9cbf48d12e1c68cfbfddae0f2060579737e5218d9ce7c2e2a) | [0xb82566db…](https://lasna.reactscan.net/tx/0xb82566dbd2375b2118d64e58bb664d08d36d09c7b3eaad2eeada28666995d4f0) | [0x3e00b09e…](https://sepolia.etherscan.io/tx/0x3e00b09e91f0019447bbbd353780890d4715f7b1914faee1f16d02d970760a5a) | **DuplicateBlocked**, nothing paid |
| PO 3004: 50 @ 40.00, invoice 7005 bills 44.00 (+10%, tolerance 2%) | [0x808d09b0…](https://sepolia.etherscan.io/tx/0x808d09b048e63a6b37104866bb248314c1b69fc7b08a5cbba015dde978462235) | [0xce2b8aea…](https://lasna.reactscan.net/tx/0xce2b8aeabff53e9aa62c5af83d33831aa66bd83506bf1946b1dc070d678078ef) | [0xaf1ef504…](https://sepolia.etherscan.io/tx/0xaf1ef50424fdf7d15f3967ac0c2e9a4e86c90ae706cac8c89d6b2fbf830f34b1) | **InvoiceHeld**, reason 1 = HOLD_PRICE |
| PO 3003: 200 ordered, 120 received, invoice 7003 bills 200 | [0x17f716e3…](https://sepolia.etherscan.io/tx/0x17f716e370fe5dcf7031a7789891f04b39548d5f0169a11cea82c2e07f22a378) | [0xf7d11fda…](https://lasna.reactscan.net/tx/0xf7d11fda3209dd7064926f03b90d52cef31006b0528bd79f44f19117943c6274) | [0xf0a27f50…](https://sepolia.etherscan.io/tx/0xf0a27f50c17ee1ac386749778d6ef22c7cd0b51b80bb0d0cbc77a2bf7237ab8b) | **InvoiceHeld**, reason 2 = HOLD_QTY |
| Invoice 7004 against non-existent PO 9999 | [0x7c06b957…](https://sepolia.etherscan.io/tx/0x7c06b957530ef30286b37de7d6a9edfe3bb4ea356fa652f69de5aa555cab2031) | [0x6a0443ee…](https://lasna.reactscan.net/tx/0x6a0443ee47b5524eb1b48e454b9e45879403603b28a063ec3b88d932784d4d65) | [0x9b5acaac…](https://sepolia.etherscan.io/tx/0x9b5acaac879340bfe6bfad69bac86a61ebab8552e3b70731eac146da777161f0) | **InvoiceHeld**, reason 4 = HOLD_NO_PO |

PO and receipt events also flowed through Lasna and updated the control's state. For example, PO 3001 is [0xce680f4d…](https://sepolia.etherscan.io/tx/0xce680f4d5500f14b91a580bbf1acd5904c29b6d8f6b17e7eccea563da0fa61c1) and GRN 3001 is [0x95e2516e…](https://sepolia.etherscan.io/tx/0x95e2516e8d1f0a85eee5eeb3f00bc1b77d551a15c8d548a96ce874df768be300). PO 3004 is [0x7175abcc…](https://sepolia.etherscan.io/tx/0x7175abcc1a334fb8f4fa861e9306c173fa6b83a4e24838304afbb73b65a33587) and GRN 3004 is [0x0414e623…](https://sepolia.etherscan.io/tx/0x0414e62371d5ee9fde619976108a1dd26c1458ccc642fab7165d75caa5a46d9b). PO 3003 is [0x22c057e2…](https://sepolia.etherscan.io/tx/0x22c057e2b89f45c523ecafccf5fc2ea7a3902b2a1c14635126a4b96f9cbc87d9) and GRN 3003 is [0x27d8501c…](https://sepolia.etherscan.io/tx/0x27d8501c78c8d86252f24a58a67a96aba68ff0e77881cfc1abf9df6461c3e882).

## Human override

| Step | Tx | Result |
|---|---|---|
| CFO releases price hold on invoice 7005 | [0xa7c9bcaf…](https://sepolia.etherscan.io/tx/0xa7c9bcaf51d578512c2c3d4af86a2714b128fcea1cc20324961e7ad41e452d2d) | 2,200 mUSD paid. Vendor total is 4,700 mUSD |

## Funding (free testnet faucets)
Redeploy used the existing Sepolia / Lasna balances on the deployer (`0x07a0d80d…1b37`), previously topped up via free faucets:
- Sepolia PoW faucet (pk910) claims: [0xa747b180…](https://sepolia.etherscan.io/tx/0xa747b180d5ca2a8b7d7b4ad3513740924a06c22b381c575ba7fe933526f3d101) and [0xd010c40b…](https://sepolia.etherscan.io/tx/0xd010c40b0daf6f72a9bfc7537a7de5edf8ef5fb50c6ef518cd580e53032cdceb)
- lREACT bought with 0.1 SepETH at the Reactive faucet contract: [0x0fd0a971…](https://sepolia.etherscan.io/tx/0x0fd0a97141132e8f6eb36a3aef711883553ecff008a340511c974cb907fb0db5)
