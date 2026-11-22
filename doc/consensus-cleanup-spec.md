# Consensus cleanup (DER, CLTV, CSV, MTP lock times): draft spec

Status: **draft for discussion.** No code, no activation height. Nothing here is decided.

This is a **soft fork**, not a hard fork: every rule below only *tightens* what a block may contain, so a block valid under the new rules is
valid under the old ones, and a node that does not upgrade keeps following the chain. What an old node cannot do is *check* the new rules,
and a miner that runs old software can build a block the upgraded nodes refuse (see "Who has to upgrade").

## Why these four

Today script verification in blocks is Bitcoin 0.6's. `OP_NOP2` and `OP_NOP3` are no-operations, signature encoding is only checked by
relay policy (`fStandardSigs`: DER and low S), `nLockTime` is read against the block's own time, and `nSequence` means nothing except the
RBF signal. That rules out what most "second layer" uses need: timelocked refunds, hash-time-locked contracts (atomic swaps, the bridge in
`contrib/bridge`, payment channels), and vaults. Time-warp is **not** on this list: LWMA (height 34000) already treats timestamps as
monotonic, caps a solve time at 6 x T and has a 5-minute future limit, so the 2012-era timestamp attacks do not apply.

## The rules (from height H)

1. **Strict DER signatures (BIP 66).** A block that contains a signature that is not strictly DER encoded is invalid. Low S stays policy.
2. **`OP_CHECKLOCKTIMEVERIFY` (BIP 65)** replaces `OP_NOP2`: the transaction fails unless its `nLockTime` is of the same kind (height or
   time) as the number on the stack and at least as large, and the input's `nSequence` is not final.
3. **Lock times against median time past (BIP 113).** `nLockTime` of a time kind is compared with the median time past of the *previous*
   block, not with the block's own time. (Today's check is `IsFinal(nHeight, GetBlockTime())` in `AcceptBlock`.)
4. **Relative lock times (BIP 68) and `OP_CHECKSEQUENCEVERIFY` (BIP 112)** replace `OP_NOP3`. Only transactions of version 2 or more
   carry sequence locks, so a version 1 transaction (every transaction in the chain's history) and the RBF signal (`nSequence` below
   `0xfffffffe`) are not affected.

## What mainnet history says

A scan of every block from 0 to 87,590 on a node of this tree (about 1,800 transactions that are not coinbases; the rest of the 89,386
are coinbases):

| Question | Count |
|---|---|
| Signatures in all inputs | 11,993 |
| ... not strictly DER encoded | **0** |
| ... strictly DER but with a high S | 6,010 (50%) |
| Outputs whose script uses `OP_NOP2` or `OP_NOP3` | **0** |
| Transactions with a version other than 1 | **0** |
| Transactions with a non-zero `nLockTime` | **0** |
| Inputs with a non-final `nSequence` | **0** |
| Outputs of type pay-to-script-hash or multisig | **0** |

So no coin in the chain can become unspendable because of rules 1 to 4, and rule 1 can be consensus. **Low S must stay policy**: half of
the chain's own signatures have a high S, and a rule that is not retroactive would still split nodes that disagree on a reorganisation
past H.

## Activation

A flag day: a block height H, the same on every node. Suggested: at least 60,000 blocks (six weeks at one block a minute) after the
release that carries it, longer if the pools say they need it. No signalling: the chain is small, and a miner vote would only measure
the two or three pools that matter, which the maintainers can simply ask. Testnet and regtest take an earlier height so the rules can be
exercised (`-forkheight` style override on regtest, as the other forks have).

## Who has to upgrade

- **Miners and pools (including merged-mining pools).** An old node builds block templates from its own pool, whose relay policy already
  requires DER and low S, so the templates it builds are valid in practice. But a pool that takes transactions from elsewhere, or a miner
  that includes a transaction by hand, could build a block the new nodes refuse. Pools should upgrade before H.
- **Exchanges and merchants.** They follow whichever chain their node follows; after H, a node that has not upgraded may show a
  confirmation for a block that the upgraded majority does not accept. Upgrade before H.
- **Wallet users.** Nothing changes for them. Nothing in the wallet creates a transaction these rules refuse.

## Open questions for the maintainers

1. Is anyone going to use time locks? (If not, the rules cost nothing but a release and a flag day, and there is no hurry.)
2. Pay-to-script-hash is never used in the history, but it is enforced in blocks: `ConnectBlock` sets `fStrictPayToScriptHash` from the
   BIP 16 switch time (1 October 2012, long before this chain), so it is always on. CLTV and CSV scripts can sit inside it. (Whether
   `IsStandard` relays such outputs still has to be checked; see 3.)
3. Relay policy for version 2 transactions and for the new opcodes (`IsStandard`).
4. H, and the release it ships in.

## Tests that would come with it

- Unit tests with the vectors from BIP 65, 66, 68, 112, 113.
- Functional tests on regtest, one per rule, each both before and after H: a block with a non-DER signature, a spend with a locktime
  not yet reached, a CSV spend one block early and on time, a lock time that is reached by the block's time but not by the median
  time past.
- `feature_cross_binary`: a node of the previous release follows the chain through H when only upgraded miners mine, and is left
  behind (not forked off by a bug) when an old miner builds a bad block.
- A mainnet replay of the whole chain with the rules switched on at height 0, which must accept every block (the scan above says it
  will; the replay proves it).
