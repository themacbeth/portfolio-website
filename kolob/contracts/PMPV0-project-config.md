# KOLOB — PMPV0 project configuration

KOLOB ships as **two Art Blocks projects** on the same core contract:

| project | supply | invocations | mint | collector-configurable PMPs |
|---|---|---|---|---|
| **Thrones** | 129 | 0–128 | fixed price | `tier` |
| **Core 15** | 15 | 0–2 great stars · 3–14 governing systems | auction | `col`, six star sliders, `archetype`, `name` |

Each project is configured once by the artist via `configureProject()` — not
through a hook contract — either directly, through the Art Blocks Creator
Dashboard, or via the AB `configure-postparams` skill. The tables below are the
exact input for each call.

`configureProject(coreContract, projectId, PMPInputConfig[] pmpInputConfigs)`

Each row is one `PMPInputConfig { key, PMPConfig }`.

`DecimalRange` values are fixed-point with **10 decimal digits** (confirmed in
`PMPV0.sol`: `_DECIMAL_PRECISION = 10 ** 10`) — `minRange`/`maxRange` must be
passed as `humanValue * 1e10`, not the raw decimal. Both columns are shown below.

---

## Project A — Thrones (129, invocations 0–128)

| key | paramType | authOption | selectOptions | minRange | maxRange | pmpLockedAfterTimestamp |
|---|---|---|---|---|---|---|
| `tier` | `Select` | `TokenOwner` | `["0","1","2"]` (Celestial, Terrestrial, Telestial) | — | — | `1792627200` (2026-10-22T00:00:00Z) |

> Note: `tier` is `TokenOwner` in the PMP config, but in production the write is
> gated to the `TierAdvance` payment wrapper via `AuthOption.Address` (see
> *Payment flow* below). The wrapper is the only entity that should be able to
> set `tier`; do **not** use `TokenOwnerAndAddress`, which would leave a free
> direct path for the owner and defeat the paid-advance gate.

---

## Project B — Core 15 (15, invocations 0–2 stars · 3–14 systems)

| key | paramType | authOption | selectOptions | minRange | maxRange | pmpLockedAfterTimestamp |
|---|---|---|---|---|---|---|
| `archetype` | `Select` | `TokenOwner` | 12 profile names, see below | — | — | — |
| `name` | `String` | `ArtistAndTokenOwner` | — | — | — | — |
| `col` | `HexColor` | `TokenOwner` | — | `0x000000` | `0xFFFFFF` | — |
| `density` | `DecimalRange` | `TokenOwner` | — | 0.30 → `3_000_000_000` | 1.00 → `10_000_000_000` | — |
| `length` | `DecimalRange` | `TokenOwner` | — | 0.40 → `4_000_000_000` | 2.00 → `20_000_000_000` | — |
| `rot` | `DecimalRange` | `TokenOwner` | — | 0.00 → `0` | 2.00 → `20_000_000_000` | — |
| `speed` | `DecimalRange` | `TokenOwner` | — | 0.20 → `2_000_000_000` | 2.50 → `25_000_000_000` | — |
| `curl` | `DecimalRange` | `TokenOwner` | — | 1.00 → `10_000_000_000` | 8.00 → `80_000_000_000` | — |
| `big` | `DecimalRange` | `TokenOwner` | — | 0.00 → `0` | 0.40 → `4_000_000_000` | — |

**`name` must be `ArtistAndTokenOwner`, not `TokenOwner`.** Per the AB review,
`configureProject()` requires `ArtistAndTokenOwner` on String params so the
artist can override submissions (e.g. hate speech). `TokenOwner` alone reverts.
`col` applies only to the three great stars (inv 0–2); `archetype` only to the
twelve systems (inv 3–14); `name` to all fifteen. The renderer and the Core 15
hook both enforce that per-invocation applicability.

`archetype` selectOptions, in index order (must match `ARCHETYPES` in
`KolobCore15Hook.sol` exactly, since the hook decodes the Select index):

```
0  RINGED DYNASTY
1  MOON SWARM
2  ASTEROID EMPIRE
3  COMET STORM
4  EMBRYO NURSERY
5  ECCENTRIC CHAOS
6  BINARY HEART
7  RESONANCE CATHEDRAL
8  FROZEN KUIPER
9  HOT-JUPITER FORGE
10 MEGA-RING WORLD
11 TROJAN SWARMS
```

---

## Register the hooks

Each project gets its own configure hook (validation-only; no augment hook — see
below). Both take their own `projectId` and enforce `tokenId / 1e6 == projectId`
so a hook can only ever govern its own project.

```solidity
// Thrones project → KolobThroneHook (tier advance-only)
PMPV0.configureProjectHooks(
    coreContract,
    thronesProjectId,
    IPMPConfigureHook(kolobThroneHookAddress),
    IPMPAugmentHook(address(0))   // no augment hook — see note below
);

// Core 15 project → KolobCore15Hook (col hue bands, archetype uniqueness, name length)
PMPV0.configureProjectHooks(
    coreContract,
    core15ProjectId,
    IPMPConfigureHook(kolobCore15HookAddress),
    IPMPAugmentHook(address(0))
);
```

## Why there's no augment hook

Every KOLOB param is a collector-configured PMP. `getTokenParams()` returns all
configured params automatically — nothing needs to be injected at read time.
`token.html` already reads them directly:

```js
const d = tokenData.externalAssetDependencies[0]?.data;
const tier = d?.tier;   // "0" | "1" | "2" | undefined   (Thrones only)
```

The one case where an augment hook would add value is giving the art script a
verifiable on-chain timestamp (so an Outer Darkness capture reflects chain time,
not the renderer's wall clock). Art Blocks has a pre-deployed standard hook for
this — `InjectBlockTimestamp` — which the Thrones project could register as its
augment hook instead of writing a custom one, if this matters. Ask the AB team
for its deployed address.

> **Lock enforcement:** AB flagged (July 2026 review) that `pmpLockedAfterTimestamp`
> is not currently enforced on write, and will patch it before this project goes
> live. Until then, `KolobThroneHook`'s advance-only check is the interim guard
> on `tier`. The Oct 22 2026 deadline itself is unaffected.

## Payment flow — TierAdvance wrapper (Thrones only)

`configureTokenParams()` is not `payable` and forwards no value, so neither
PMPV0 nor a configure hook can gate on payment — the hook never sees ETH.
Payment lives in a separate contract, `TierAdvance` (see `TierAdvance.sol`),
which AB endorsed as "Option A" in review:

1. `tier`'s `authOption` is `Address` with `authAddress = TierAdvance`. Only the
   wrapper can write `tier`.
2. Collector calls `TierAdvance.advance{value: …}(tokenId, newTier)`.
3. Wrapper verifies the caller controls the token via
   `PMPV0.isTokenOwnerOrDelegate(msg.sender, coreContract, tokenId)` — reuses
   PMPV0's own delegate.xyz logic.
4. Wrapper reads the current tier from PMPV0 storage (treating unconfigured as
   Telestial = 2), computes `steps = current − newTier`, and requires
   `msg.value >= advanceFee * steps`.
5. Wrapper forwards ETH to the **KOLOB primary-sales splitter** (AB requests the
   standard primary-sales splits be honored on these follow-up advance txns),
   then calls `PMPV0.configureTokenParams(coreContract, tokenId, [tierInput])`.
   PMPV0 authenticates the wrapper as the `Address` role, and `KolobThroneHook`
   still enforces advance-only.

Needed from AB to finalize the wrapper: the two **projectIds**, the
**primary-sales splitter address**, and confirmation of the exact PMPV0 helper
signatures (`isTokenOwnerOrDelegate`, current-value read).

## Encoding — confirmed against PMPV0.sol source

Read directly from `ArtBlocks/artblocks-contracts` (`web3call/PMPV0.sol`):
  - `Select`: `uint256(pmpInput.configuredValue)` is the index into
    `selectOptions` (`selectOptions.get(uint256(pmp.configuredValue))`)
  - `HexColor`: 24-bit `0xRRGGBB`, right-aligned in `configuredValue`
    (`_uintToHexColorString`)
  - `DecimalRange`: 10-decimal fixed point, see tables above
    (`_DECIMAL_PRECISION = 10 ** 10`)
  - `String`: **no native length bound** — confirmed by reading
    `_validatePMPInputAndAuth`, which only checks that `configuredValue` is
    empty for String-type params. This is why `KolobCore15Hook`'s 24-byte
    `name` check is load-bearing, not just precautionary.
  - `tokenId = projectId * 1_000_000 + invocation` — confirmed in
    docs.artblocks.io/developer/core-contract/. Both hooks derive
    `inv = tokenId % 1_000_000` and enforce `tokenId / 1_000_000 == projectId`.
