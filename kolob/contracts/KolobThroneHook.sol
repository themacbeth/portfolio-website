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
 * @title  KolobThroneHook
 * @notice PostParam configure hook for the KOLOB *Thrones* project (129 tokens,
 *         invocations 0-128). KOLOB ships as two Art Blocks projects; this hook
 *         governs only the Thrones project, whose sole collector-configurable
 *         param is `tier`. The Core 15 project has its own hook
 *         (KolobCore15Hook) for `col` / `archetype` / `name`.
 *
 *         Called by PMPV0 AFTER a param write is already stored; revert here to
 *         roll back the collector's entire configureTokenParams() transaction.
 *
 * ── What PMPV0 already enforces natively (via configureProject) ──────────────
 *     - Select option list for `tier` (["0","1","2"], rejects unknown values)
 *     - pmpLockedAfterTimestamp — freezes `tier` at the Outer Darkness deadline
 *       (1792627200 = 2026-10-22T00:00:00Z)
 *
 * ── What this hook adds ──────────────────────────────────────────────────────
 *     tier   one-directional advance only (Celestial 0 ← Terrestrial 1 ←
 *            Telestial 2). Select alone would permit any option in any
 *            direction before the lock date.
 *
 * ── Encoding (confirmed vs. PMPV0.sol, ArtBlocks/artblocks-contracts) ─────────
 *     Select: uint256(pmpInput.configuredValue) == index into selectOptions.
 *
 * ── Deployment ───────────────────────────────────────────────────────────────
 *     PMPV0  0x00000000A78E278b2d2e2935FaeBe19ee9F1FF14  (same address, all chains)
 */
contract KolobThroneHook is IPMPConfigureHook {

    // ── immutables ─────────────────────────────────────────────────────────────
    address public immutable pmpV0;
    address public immutable coreContract;   // KOLOB's Art Blocks core contract
    uint256 public immutable projectId;      // the Thrones project id
    uint256 public immutable deadline;       // 1792627200 = 2026-10-22T00:00:00Z

    // ── tier state ─────────────────────────────────────────────────────────────
    // We track each throne's last-sealed tier ourselves rather than reading it
    // back from PMPV0. The configure hook fires AFTER the new value is already
    // stored, so getTokenParams() would return the incoming value, not the prior
    // one — every advance would then compare a value against itself and revert.
    mapping(uint256 => uint8) private _tier;      // invocation -> last-sealed tier index
    mapping(uint256 => bool)  private _tierSet;   // invocation -> has advanced at least once

    // ── constants ──────────────────────────────────────────────────────────────
    uint8 internal constant TIER_CELESTIAL   = 0;
    uint8 internal constant TIER_TERRESTRIAL = 1;
    uint8 internal constant TIER_TELESTIAL   = 2;

    uint256 internal constant INV_THRONE_END = 128;   // 129 thrones, invocations 0-128

    // ── errors ─────────────────────────────────────────────────────────────────
    error NotPMPV0();
    error WrongCoreContract();
    error WrongProject();
    error WrongTokenKind(string key);
    error TierMustAdvance(uint8 current, uint8 given);

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
        if (msg.sender != pmpV0) revert NotPMPV0();
        if (_coreContract != coreContract) revert WrongCoreContract();
        // Enforce this hook only ever governs its own project, even if it were
        // mistakenly registered elsewhere on the same core contract.
        if (tokenId / 1_000_000 != projectId) revert WrongProject();

        uint256 inv = tokenId % 1_000_000; // AB V3: tokenId = projectId*1e6 + invocation
        bytes32 keyHash = keccak256(bytes(pmpInput.key));

        if (keyHash == keccak256("tier")) { _checkTier(inv, pmpInput); return; }
        // Thrones expose no other collector-configurable param; anything else
        // is out of scope and passes through untouched.
    }

    // ── validator ────────────────────────────────────────────────────────────

    function _checkTier(uint256 inv, IPMPV0.PMPInput calldata pmpInput) internal {
        if (inv > INV_THRONE_END) revert WrongTokenKind("tier");

        uint8 newTier = uint8(uint256(pmpInput.configuredValue)); // Select index, confirmed vs. PMPV0.sol
        // Prior tier from our own registry: a throne that has never advanced
        // defaults to Telestial. See the `_tier`/`_tierSet` note above for why
        // we don't read this back from PMPV0.
        uint8 curTier = _tierSet[inv] ? _tier[inv] : TIER_TELESTIAL;

        // Advance-only: new tier must be strictly inward (lower index).
        // Native pmpLockedAfterTimestamp on this key already freezes the value
        // entirely once `deadline` passes — this check only guards the window
        // *before* that lock.
        if (newTier >= curTier) revert TierMustAdvance(curTier, newTier);

        // Seal the new tier. If any later step in the collector's
        // configureTokenParams() tx reverts, this write rolls back with it.
        _tier[inv]    = newTier;
        _tierSet[inv] = true;
    }
}
