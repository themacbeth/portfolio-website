# KOLOB — PMPV0 project configuration

Most of what `KolobConfigureHook.sol` used to hand-roll (ranges, allowed
options, the Outer Darkness lock date) is actually native to PMPV0. It's set
once by the artist via `configureProject()` — not through a hook contract —
either directly, through the Art Blocks Creator Dashboard, or via the AB
`configure-postparams` skill. This table is the exact input for that call.

`configureProject(coreContract, projectId, PMPInputConfig[] pmpInputConfigs)`

Each row below is one `PMPInputConfig { key, PMPConfig }`.

`DecimalRange` values are fixed-point with **10 decimal digits** (confirmed in
`PMPV0.sol`: `_DECIMAL_PRECISION = 10 ** 10`) — `minRange`/`maxRange` must be
passed as `humanValue * 1e10`, not the raw decimal. Both columns are shown below.

| key | paramType | authOption | selectOptions | minRange | maxRange | pmpLockedAfterTimestamp |
|---|---|---|---|---|---|---|
| `tier` | `Select` | `TokenOwner` | `["0","1","2"]` (Celestial, Terrestrial, Telestial) | — | — | `1761091200` (2026-10-22T00:00:00Z) |
| `archetype` | `Select` | `TokenOwner` | 12 profile names, see below | — | — | — |
| `name` | `String` | `TokenOwner` | — | — | — | — |
| `col` | `HexColor` | `TokenOwner` | — | `0x000000` | `0xFFFFFF` | — |
| `density` | `DecimalRange` | `TokenOwner` | — | 0.30 → `3_000_000_000` | 1.00 → `10_000_000_000` | — |
| `length` | `DecimalRange` | `TokenOwner` | — | 0.40 → `4_000_000_000` | 2.00 → `20_000_000_000` | — |
| `rot` | `DecimalRange` | `TokenOwner` | — | 0.00 → `0` | 2.00 → `20_000_000_000` | — |
| `speed` | `DecimalRange` | `TokenOwner` | — | 0.20 → `2_000_000_000` | 2.50 → `25_000_000_000` | — |
| `curl` | `DecimalRange` | `TokenOwner` | — | 1.00 → `10_000_000_000` | 8.00 → `80_000_000_000` | — |
| `big` | `DecimalRange` | `TokenOwner` | — | 0.00 → `0` | 0.40 → `4_000_000_000` | — |

`archetype` selectOptions, in index order (must match `ARCHETYPES` in
`KolobConfigureHook.sol` exactly, since the hook decodes the Select index):

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

## Register the hook

Separately from `configureProject()`, register `KolobConfigureHook` for
validation-only (no augment hook needed — see below):

```solidity
PMPV0.configureProjectHooks(
    coreContract,
    projectId,
    IPMPConfigureHook(kolobConfigureHookAddress),
    IPMPAugmentHook(address(0))   // no augment hook — see note below
);
```

## Why there's no augment hook

Every KOLOB param (`tier`, `archetype`, `name`, `col`, and the six star
sliders) is a collector-configured PMP. `getTokenParams()` returns all
configured params automatically — nothing needs to be injected at read time.
`token.html` already reads them directly:

```js
const d = tokenData.externalAssetDependencies[0]?.data;
const tier = d?.tier;   // "0" | "1" | "2" | undefined
```

The one case where an augment hook would add real value is giving the art
script a verifiable on-chain timestamp (so an Outer Darkness capture reflects
chain time, not the renderer's wall clock). Art Blocks already has a
**pre-deployed standard hook for this** — `InjectBlockTimestamp` — so KOLOB
should register that as the augment hook instead of writing a custom one, if
this matters. Ask the AB team for its deployed address before Studio setup.

## Payment flow — open question

`configureTokenParams()` has no built-in ETH handling. The mint page
advertises "+0.04 ETH to move inward" for a throne, but PMPV0 itself won't
collect that. Confirm with the AB team how tier-advance payment is meant to
gate the `tier` write — likely either:
  - a separate payable contract that calls `configureTokenParams()` on the
    collector's behalf once payment clears, with `AuthOption.Address` set to
    that contract, or
  - a minter-suite flow that isn't part of the PMP hook system at all.

## Encoding — confirmed against PMPV0.sol source

Read directly from `ArtBlocks/artblocks-contracts` (`web3call/PMPV0.sol`),
not just the docs site — all previously-assumed encodings check out:
  - `Select`: `uint256(pmpInput.configuredValue)` is the index into
    `selectOptions` (`selectOptions.get(uint256(pmp.configuredValue))`)
  - `HexColor`: 24-bit `0xRRGGBB`, right-aligned in `configuredValue`
    (`_uintToHexColorString`)
  - `DecimalRange`: 10-decimal fixed point, see table above
    (`_DECIMAL_PRECISION = 10 ** 10`)
  - `String`: **no native length bound** — confirmed by reading
    `_validatePMPInputAndAuth`, which only checks that `configuredValue` is
    empty for String-type params. This is why `KolobConfigureHook`'s 24-byte
    `name` check is load-bearing, not just precautionary.
  - `tokenId = projectId * 1_000_000 + invocation` — confirmed in
    docs.artblocks.io/developer/core-contract/.

Still open — not in the source or docs, needs an actual answer from AB:
  - the ETH-payment gating pattern for the `tier` advance flow (see below)
  - whether `configureProjectHooks()` accepts `address(0)` for an unused
    augment-hook slot
