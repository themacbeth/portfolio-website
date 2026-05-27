// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title KolobArchetypeValidator
/// @notice Art Blocks Engine Flex PMP validator. Enforces that no two
///         Core-System tokens (invocation 3-14) can hold the same
///         `archetype` value at the same time. First-come, first-serve:
///         when a token claims an archetype, that archetype becomes
///         unavailable to every other core until released or overwritten
///         by the same token.
/// @dev    Attached to the `archetype` PMP key. The PMP system calls
///         `validate(...)` before applying a write; reverting (or
///         returning false in the projected interface) rejects the write.
///         The Engine Flex PMP interface is a moving target across core
///         versions, so this file presents the canonical rule and the
///         storage. Wire it through whichever validator hook your PMP
///         contract version exposes (`onUpdate`, `validate`, or a
///         pre-write callback).
///
///         Read paths:
///           archetypeHolder(projectId, archetypeId) -> tokenId or 0
///           archetypeOf(tokenId)                    -> archetypeId or -1
contract KolobArchetypeValidator {
    /// @notice The project these rules apply to.
    uint256 public immutable PROJECT_ID;

    /// @notice The invocation range that is a Core System (inclusive).
    ///         For KOLOB: 3 .. 14.
    uint256 public constant CORE_INV_MIN = 3;
    uint256 public constant CORE_INV_MAX = 14;

    /// @notice The range of valid archetype ids (inclusive). Twelve
    ///         archetypes: 0 Ringed Dynasty .. 11 Trojan Swarms.
    uint256 public constant ARCHETYPE_MAX = 11;

    /// @notice The PMP key this validator governs.
    bytes32 public constant KEY = keccak256("archetype");

    /// @dev archetypeId => tokenId currently holding it (0 == unclaimed).
    ///      tokenId 0 is treated as "unclaimed"; KOLOB tokenIds start
    ///      from the project's first minted token, never zero.
    mapping(uint256 => uint256) private _holder;

    /// @dev tokenId => archetypeId currently held (0 default; check
    ///      `_hasClaim[tokenId]` to disambiguate from "actually holding 0").
    mapping(uint256 => uint256) private _claim;
    mapping(uint256 => bool)    private _hasClaim;

    /// @notice Authoritative PMP contract that may call the hook.
    address public immutable PMP;

    error NotPmp();
    error WrongProject(uint256 got);
    error NotCoreInvocation(uint256 tokenId, uint256 inv);
    error ArchetypeOutOfRange(uint256 archetype);
    error ArchetypeAlreadyClaimed(uint256 archetype, uint256 holder);

    event ArchetypeClaimed(uint256 indexed tokenId, uint256 indexed archetype);
    event ArchetypeReleased(uint256 indexed tokenId, uint256 indexed archetype);

    constructor(uint256 projectId, address pmpContract) {
        PROJECT_ID = projectId;
        PMP = pmpContract;
    }

    modifier onlyPmp() {
        if (msg.sender != PMP) revert NotPmp();
        _;
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Core validation hook
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Called by the PMP contract before applying an `archetype`
    ///         write. Reverts if the rule is violated, otherwise records
    ///         the new claim atomically.
    /// @param projectId     The Art Blocks project id.
    /// @param tokenId       The token whose PMP is being updated.
    /// @param invocation    The token's invocation number within the project.
    /// @param archetype     The new archetype value the owner is writing.
    function onArchetypeWrite(
        uint256 projectId,
        uint256 tokenId,
        uint256 invocation,
        uint256 archetype
    ) external onlyPmp {
        if (projectId != PROJECT_ID)               revert WrongProject(projectId);
        if (invocation < CORE_INV_MIN ||
            invocation > CORE_INV_MAX)             revert NotCoreInvocation(tokenId, invocation);
        if (archetype > ARCHETYPE_MAX)             revert ArchetypeOutOfRange(archetype);

        uint256 holder = _holder[archetype];
        if (holder != 0 && holder != tokenId) {
            revert ArchetypeAlreadyClaimed(archetype, holder);
        }

        // Release this token's previous claim, if any.
        if (_hasClaim[tokenId]) {
            uint256 prev = _claim[tokenId];
            if (prev != archetype) {
                delete _holder[prev];
                emit ArchetypeReleased(tokenId, prev);
            }
        }

        _holder[archetype]  = tokenId;
        _claim[tokenId]     = archetype;
        _hasClaim[tokenId]  = true;
        emit ArchetypeClaimed(tokenId, archetype);
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Read paths
    // ─────────────────────────────────────────────────────────────────────

    /// @notice tokenId currently holding `archetype`, or 0 if unclaimed.
    function archetypeHolder(uint256 archetype) external view returns (uint256) {
        return _holder[archetype];
    }

    /// @notice The archetype `tokenId` currently claims. Returns (0,false)
    ///         if the token has never claimed.
    function archetypeOf(uint256 tokenId)
        external view returns (uint256 archetype, bool claimed)
    {
        return (_claim[tokenId], _hasClaim[tokenId]);
    }
}
