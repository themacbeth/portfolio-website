// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.22;

// ─── Imports ────────────────────────────────────────────────────────────────
//   IPMPV0.sol            — artblocks-contracts/.../interfaces/v0.8.x/IPMPV0.sol
//   IPMPConfigureHook.sol — same directory
//   IWeb3Call.sol         — same directory (defines TokenParam, pulled in via IPMPV0)
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IPMPV0} from "./interfaces/IPMPV0.sol";
import {IPMPConfigureHook} from "./interfaces/IPMPConfigureHook.sol";

/**
 * @title  KolobCore15Hook
 * @notice PostParam configure hook for the KOLOB *Core 15* project (15 tokens,
 *         invocations 0-2 great stars · 3-14 governing systems). KOLOB ships as
 *         two Art Blocks projects; this hook governs only the Core 15 project.
 *         The Thrones project has its own hook (KolobThroneHook) for `tier`.
 *
 *         Called by PMPV0 AFTER a param write is already stored; revert here to
 *         roll back the collector's entire configureTokenParams() transaction.
 *
 * ── What PMPV0 already enforces natively (via configureProject) ──────────────
 *     - ParamType + Select option list for `archetype` (rejects unknown values)
 *     - DecimalRange min/max for density / length / rot / speed / curl / big
 *       (pure range fields, intentionally absent from this contract)
 *     - HexColor 24-bit range for `col`
 *
 * ── What this hook adds (constraints PMPV0 can't express natively) ────────────
 *     archetype  global first-come exclusivity across the 12 governing systems,
 *                and immutability once a token has sealed a choice
 *     name       String has no native length bound (24-byte cap here)
 *     col        HexColor's native range is a flat numeric range, not a circular
 *                per-star hue band, and does not reject the achromatic axis
 *
 * ── configureProject note ────────────────────────────────────────────────────
 *     `name` is a String param and MUST be configured with authOption
 *     ArtistAndTokenOwner (not TokenOwner) so the artist retains override — see
 *     PMPV0-project-config.md. This hook enforces length regardless of author.
 *
 * ── Encoding (confirmed vs. PMPV0.sol, ArtBlocks/artblocks-contracts) ─────────
 *     Select:   uint256(configuredValue) == index into selectOptions.
 *     HexColor: uint256(configuredValue) == 0x00..RRGGBB, 24-bit, right-aligned.
 *     String:   PMPV0 imposes NO native length bound — the `name` check below is
 *               load-bearing, not precautionary.
 *
 * ── Deployment ───────────────────────────────────────────────────────────────
 *     PMPV0  0x00000000A78E278b2d2e2935FaeBe19ee9F1FF14  (same address, all chains)
 */
contract KolobCore15Hook is IPMPConfigureHook {

    // ── immutables ─────────────────────────────────────────────────────────────
    address public immutable pmpV0;
    address public immutable coreContract;   // KOLOB's Art Blocks core contract
    uint256 public immutable projectId;      // the Core 15 project id

    // ── archetype state ────────────────────────────────────────────────────────
    // Global first-come claim registry + per-token immutability flag. Neither is
    // ever cleared, matching "no two sealed systems can ever share an archetype".
    mapping(bytes32 => bool) private _profileClaimed;   // keccak256(profileName) -> claimed
    mapping(uint256 => bool) private _archetypeSet;      // invocation -> sealed

    // ── constants ──────────────────────────────────────────────────────────────
    // Hue centers in degrees (from kolob-pod-1d.html SUN_HUES): gold, blue, red
    uint16 internal constant HUE_BAND = 30;   // +/- 30 degrees allowed
    uint16 internal constant HUE_GOLD = 46;   // inv 0 - Oleblish
    uint16 internal constant HUE_BLUE = 207;  // inv 1 - Enish-go-on-dosh
    uint16 internal constant HUE_RED  = 15;   // inv 2 - Kai-e-vanrash

    uint256 internal constant INV_STARS_END    = 2;    // great stars: invocations 0-2
    uint256 internal constant INV_CORE12_START = 3;    // governing systems: 3-14
    uint256 internal constant INV_CORE12_END   = 14;

    // ── errors ─────────────────────────────────────────────────────────────────
    error NotPMPV0();
    error WrongCoreContract();
    error WrongProject();
    error WrongTokenKind(string key);
    error UnknownArchetype(uint256 optionIndex);
    error ArchetypeClaimed(string profile);
    error ArchetypeAlreadySet(uint256 invocation);
    error NameTooLong(uint256 byteLen);
    error HueBandViolation(uint256 starIdx, uint16 hue, uint16 center);
    error AchromaticColor(uint256 starIdx);

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
        uint256 _projectId
    ) {
        pmpV0        = _pmpV0;
        coreContract = _coreContract;
        projectId    = _projectId;
    }

    // ── ERC165 ───────────────────────────────────────────────────────────────

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
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
        // Only PMPV0 may call this — prevents forged calls that could poison the
        // persistent archetype-claim registry below.
        if (msg.sender != pmpV0) revert NotPMPV0();
        if (_coreContract != coreContract) revert WrongCoreContract();
        // Enforce this hook only ever governs its own project, even if it were
        // mistakenly registered elsewhere on the same core contract.
        if (tokenId / 1_000_000 != projectId) revert WrongProject();

        uint256 inv = tokenId % 1_000_000; // AB V3: tokenId = projectId*1e6 + invocation
        bytes32 keyHash = keccak256(bytes(pmpInput.key));

        if (keyHash == keccak256("archetype")) { _checkArchetype(inv, pmpInput); return; }
        if (keyHash == keccak256("name"))      { _checkName(inv, pmpInput);      return; }
        if (keyHash == keccak256("col"))       { _checkCol(inv, pmpInput);       return; }
        // density/length/rot/speed/curl/big: no custom validation, bounds are
        // enforced natively by PMPV0's DecimalRange min/max.
    }

    // ── validators ─────────────────────────────────────────────────────────────

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
        if (inv > INV_STARS_END) revert WrongTokenKind("col"); // Great Stars only: inv 0-2

        // 24-bit RGB packed right-aligned in configuredValue, confirmed vs. PMPV0.sol.
        uint256 packed = uint256(pmpInput.configuredValue);
        uint8 r = uint8(packed >> 16);
        uint8 g = uint8(packed >> 8);
        uint8 b = uint8(packed);

        // Reject fully-desaturated colours (r==g==b: gray/white/black). They have
        // no hue, so _hueDegrees() returns 0 — which falls inside the red band
        // (center 15°) and would let Kai-e-vanrash be set to white/gray/black,
        // defeating the "three suns always read as distinct" guarantee.
        uint8 mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
        uint8 mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (mx == mn) revert AchromaticColor(inv);

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
}
