// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.22;

// ─── Imports ────────────────────────────────────────────────────────────────
//
// Copy these three interface files from artblocks-contracts into
// src/interfaces/, or `npm install @artblocks/contracts @openzeppelin/contracts`
// and adjust the paths below.
//
//   IPMPV0.sol            — artblocks-contracts/.../interfaces/v0.8.x/IPMPV0.sol
//   IPMPConfigureHook.sol — same directory
//   IWeb3Call.sol         — same directory (defines TokenParam, pulled in via IPMPV0)
//
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IPMPV0} from "./interfaces/IPMPV0.sol";
import {IPMPConfigureHook} from "./interfaces/IPMPConfigureHook.sol";

/**
 * @title  KolobConfigureHook
 * @notice PostParam configure hook for KOLOB. Called by PMPV0 AFTER a param
 *         write is already stored; revert here to roll back the collector's
 *         entire configureTokenParams() transaction.
 *
 * ── Why this contract is short ───────────────────────────────────────────────
 *
 *   PMPV0 already natively enforces, per-key, via configureProject()
 *   (an artist-only call — see PMPV0-project-config.md in this folder):
 *     - ParamType + Select option lists (rejects unknown values)
 *     - Uint256Range / DecimalRange min/max bounds
 *     - pmpLockedAfterTimestamp (used for the Outer Darkness deadline lock)
 *
 *   This hook exists ONLY for the constraints PMPV0 cannot express natively:
 *
 *   key        rule PMPV0 can't enforce on its own
 *   ─────────  ──────────────────────────────────────────────────────────────
 *   tier       one-directional advance (Select alone permits any option,
 *              any direction, at any time before the lock date)
 *   archetype  global first-come exclusivity across the 12 Core tokens, and
 *              immutability once a token has sealed a choice
 *   name       String has no native length bound
 *   col        HexColor's native range is a flat numeric range, not a
 *              circular hue-band constraint per star
 *
 *   density / length / rot / speed / curl / big are pure DecimalRange fields
 *   with project-configured min/max — no custom logic needed, intentionally
 *   absent from this contract.
 *
 * ── Encoding notes (confirmed against PMPV0.sol source, ArtBlocks/artblocks-contracts) ──
 *
 *   Read directly from the deployed contract's _getPMPValue / _validatePMPInputAndAuth:
 *     - Select:       uint256(pmpInput.configuredValue) == index into selectOptions
 *                      (PMPV0.sol: `selectOptions.get(uint256(pmp.configuredValue))`)
 *     - HexColor:      uint256(pmpInput.configuredValue) == 0x00..RRGGBB, 24-bit,
 *                      right-aligned (PMPV0.sol: `_uintToHexColorString`)
 *     - DecimalRange:  fixed-point, 10 decimal digits — a value of 0.30 is stored
 *                      as `0.30 * 1e10 = 3_000_000_000` (PMPV0.sol: `_DECIMAL_PRECISION
 *                      = 10 ** 10`). Not read by this contract, but needed when calling
 *                      configureProject() — see PMPV0-project-config.md.
 *     - String:        PMPV0 has NO native length bound on configuredValueString —
 *                      confirmed by reading _validatePMPInputAndAuth, which only checks
 *                      configuredValue is empty for String-type params. This is why the
 *                      `name` check below is necessary, not just precautionary.
 *
 * ── Deployment ────────────────────────────────────────────────────────────────
 *   PMPV0    0x00000000A78E278b2d2e2935FaeBe19ee9F1FF14  (same address, all chains)
 */
contract KolobConfigureHook is IPMPConfigureHook {

    // ── immutables ─────────────────────────────────────────────────────────────
    address public immutable pmpV0;
    address public immutable coreContract;   // KOLOB's Art Blocks core contract
    uint256 public immutable projectId;
    uint256 public immutable deadline;       // 1761091200 = 2026-10-22T00:00:00Z

    // ── archetype state ────────────────────────────────────────────────────────
    // Global first-come claim registry + per-token immutability flag. Neither
    // is ever cleared, matching "no two sealed cores can ever share an archetype".
    mapping(bytes32 => bool) private _profileClaimed;   // keccak256(profileName) -> claimed
    mapping(uint256 => bool) private _archetypeSet;      // invocation -> sealed

    // ── constants ──────────────────────────────────────────────────────────────
    // Hue centers in degrees (from kolob-pod-1d.html SUN_HUES): gold, blue, red
    uint16 internal constant HUE_BAND = 30;   // +/- 30 degrees allowed
    uint16 internal constant HUE_GOLD = 46;   // inv 0 - Oleblish
    uint16 internal constant HUE_BLUE = 207;  // inv 1 - Enish-go-on-dosh
    uint16 internal constant HUE_RED  = 15;   // inv 2 - Kai-e-vanrash

    uint8 internal constant TIER_CELESTIAL   = 0;
    uint8 internal constant TIER_TERRESTRIAL = 1;
    uint8 internal constant TIER_TELESTIAL   = 2;

    uint256 internal constant INV_STARS_END    = 2;
    uint256 internal constant INV_CORE12_START = 3;
    uint256 internal constant INV_CORE12_END   = 14;
    uint256 internal constant INV_THRONE_START = 15;
    uint256 internal constant INV_THRONE_END   = 143;

    // ── errors ─────────────────────────────────────────────────────────────────
    error NotPMPV0();
    error WrongCoreContract();
    error WrongTokenKind(string key);
    error TierMustAdvance(uint8 current, uint8 given);
    error UnknownArchetype(uint256 optionIndex);
    error ArchetypeClaimed(string profile);
    error ArchetypeAlreadySet(uint256 invocation);
    error NameTooLong(uint256 byteLen);
    error HueBandViolation(uint256 starIdx, uint16 hue, uint16 center);

    // The 12 profiles from CORE_PROFILES in kolob-pod-1d.html, in Select option order.
    // Confirm this matches the actual selectOptions[] passed to configureProject().
    string[12] internal ARCHETYPES = [
        "RINGED DYNASTY", "MOON SWARM", "ASTEROID EMPIRE",
        "COMET STORM", "EMBRYO NURSERY", "ECCENTRIC CHAOS", "BINARY HEART",
        "RESONANCE CATHEDRAL", "FROZEN KUIPER", "HOT-JUPITER FORGE",
        "MEGA-RING WORLD", "TROJAN SWARMS"
    ];

    constructor(
        address _pmpV0,
        address _coreContract,
        uint256 _projectId,
        uint256 _deadline
    ) {
        pmpV0        = _pmpV0;
        coreContract = _coreContract;
        projectId    = _projectId;
        deadline     = _deadline;
    }

    // ── ERC165 ───────────────────────────────────────────────────────────────

    function supportsInterface(bytes4 interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return interfaceId == type(IPMPConfigureHook).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    // ── hook entry point ──────────────────────────────────────────────────────

    /// @dev Revert to block the collector's configureTokenParams() transaction.
    function onTokenPMPConfigure(
        address _coreContract,
        uint256 tokenId,
        IPMPV0.PMPInput calldata pmpInput
    ) external override {
        // Only PMPV0 may call this — prevents forged calls that could poison
        // the persistent archetype-claim registry below.
        if (msg.sender != pmpV0) revert NotPMPV0();
        if (_coreContract != coreContract) revert WrongCoreContract();

        uint256 inv = tokenId % 1_000_000; // AB V3: tokenId = projectId*1e6 + invocation
        bytes32 keyHash = keccak256(bytes(pmpInput.key));

        if (keyHash == keccak256("tier"))      { _checkTier(inv, tokenId, pmpInput);      return; }
        if (keyHash == keccak256("archetype")) { _checkArchetype(inv, pmpInput);           return; }
        if (keyHash == keccak256("name"))      { _checkName(inv, pmpInput);                return; }
        if (keyHash == keccak256("col"))       { _checkCol(inv, pmpInput);                 return; }
        // density/length/rot/speed/curl/big: no custom validation, bounds are
        // enforced natively by PMPV0's DecimalRange min/max.
    }

    // ── validators ─────────────────────────────────────────────────────────────

    function _checkTier(uint256 inv, uint256 tokenId, IPMPV0.PMPInput calldata pmpInput) internal view {
        if (inv < INV_THRONE_START || inv > INV_THRONE_END) revert WrongTokenKind("tier");

        uint8 newTier = uint8(uint256(pmpInput.configuredValue)); // Select index, confirmed vs. PMPV0.sol
        uint8 curTier = _currentTier(tokenId);

        // Advance-only: new tier must be strictly inward (lower index).
        // Native pmpLockedAfterTimestamp on this key already freezes the
        // value entirely once `deadline` passes — this check only guards
        // the window *before* that lock.
        if (newTier >= curTier) revert TierMustAdvance(curTier, newTier);
    }

    function _checkArchetype(uint256 inv, IPMPV0.PMPInput calldata pmpInput) internal {
        if (inv < INV_CORE12_START || inv > INV_CORE12_END) revert WrongTokenKind("archetype");
        if (_archetypeSet[inv]) revert ArchetypeAlreadySet(inv);

        uint256 idx = uint256(pmpInput.configuredValue); // Select index, confirmed vs. PMPV0.sol
        if (idx >= ARCHETYPES.length) revert UnknownArchetype(idx);

        bytes32 ph = keccak256(bytes(ARCHETYPES[idx]));
        if (_profileClaimed[ph]) revert ArchetypeClaimed(ARCHETYPES[idx]);

        _profileClaimed[ph] = true;
        _archetypeSet[inv]  = true;
    }

    function _checkName(uint256 inv, IPMPV0.PMPInput calldata pmpInput) internal pure {
        if (inv > INV_CORE12_END) revert WrongTokenKind("name"); // Core 15 only: inv 0-14
        uint256 len = bytes(pmpInput.configuredValueString).length;
        if (len > 24) revert NameTooLong(len);
    }

    function _checkCol(uint256 inv, IPMPV0.PMPInput calldata pmpInput) internal pure {
        if (inv > INV_STARS_END) revert WrongTokenKind("col"); // Great Suns only: inv 0-2

        // 24-bit RGB packed right-aligned in configuredValue, confirmed vs. PMPV0.sol.
        uint256 packed = uint256(pmpInput.configuredValue);
        uint8 r = uint8(packed >> 16);
        uint8 g = uint8(packed >> 8);
        uint8 b = uint8(packed);

        uint16 h = _hueDegrees(r, g, b);
        uint16 center = inv == 0 ? HUE_GOLD : (inv == 1 ? HUE_BLUE : HUE_RED);
        if (!_inBand(h, center)) revert HueBandViolation(inv, h, center);
    }

    // ── hue math ───────────────────────────────────────────────────────────────

    function _hueDegrees(uint8 r, uint8 g, uint8 b) internal pure returns (uint16) {
        uint8 mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
        uint8 mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (mx == mn) return 0;

        int256 d = int256(uint256(mx - mn));
        int256 h;

        if (mx == r) {
            h = 60 * (int256(uint256(g)) - int256(uint256(b))) / d;
            if (h < 0) h += 360;
        } else if (mx == g) {
            h = 60 * (int256(uint256(b)) - int256(uint256(r))) / d + 120;
        } else {
            h = 60 * (int256(uint256(r)) - int256(uint256(g))) / d + 240;
        }
        return uint16(uint256(h));
    }

    function _inBand(uint16 h, uint16 center) internal pure returns (bool) {
        uint256 diff = h > center
            ? uint256(h)      - uint256(center)
            : uint256(center) - uint256(h);
        if (diff > 180) diff = 360 - diff;
        return diff <= uint256(HUE_BAND);
    }

    // ── helpers ────────────────────────────────────────────────────────────────

    /// @dev Reads the token's currently-stored tier via PMPV0.getTokenParams().
    ///      Defaults to Telestial (2) if never configured (fresh mint).
    function _currentTier(uint256 tokenId) internal view returns (uint8) {
        IPMPV0.TokenParam[] memory params = IPMPV0(pmpV0).getTokenParams(coreContract, tokenId);
        for (uint256 i = 0; i < params.length; i++) {
            if (keccak256(bytes(params[i].key)) == keccak256("tier")) {
                // getTokenParams returns string values (per IWeb3Call) — parse decimal digit.
                bytes memory v = bytes(params[i].value);
                if (v.length == 1 && v[0] >= 0x30 && v[0] <= 0x39) {
                    return uint8(uint8(v[0]) - 0x30);
                }
            }
        }
        return TIER_TELESTIAL;
    }
}
