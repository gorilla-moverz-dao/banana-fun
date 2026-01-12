# Security Audit Report: NFT Launchpad Move Contracts

**Date:** January 12, 2026  
**Auditor:** Security Review  
**Scope:** `launchpad.move`, `vesting.move`, `dex.move`, `nft_reduction_manager.move`

---

## Executive Summary

This security audit reviews four Move smart contracts for an NFT launchpad with integrated token creation, vesting, and DEX liquidity pool functionality. The review identified several issues ranging from informational to medium severity.

---

## Findings Summary

| ID    | Severity | Title                                                | Status |
| ----- | -------- | ---------------------------------------------------- | ------ |
| AC-01 | Medium   | Admin Bypass via Object Owner                        | Open   |
| AC-02 | High     | Single-Step Admin Transfer in Reduction Manager      | Open   |
| AC-03 | Medium   | No Timelock on Privileged Operations                 | Open   |
| AC-04 | Low      | Creator Functions Enable Front-Running               | Open   |
| AC-05 | Info     | Sale Completion Callable by Anyone                   | Open   |
| AR-01 | Low      | Vesting Token Dust Loss Due to Rounding              | Open   |
| AR-02 | Info     | Protocol Fee Reduction Rounding Favors Protocol      | Open   |
| SM-01 | Low      | Potential Underflow in Refund Tracking               | Open   |
| SM-02 | Info     | Sale Completion Not Atomic                           | Open   |
| EC-01 | High     | Free Mint Causes LP Creation Failure                 | Open   |
| EC-02 | Medium   | Initial LP Price Manipulation                        | Open   |
| IV-01 | Low      | Zero Duration Vesting Allows Immediate Claim         | Open   |
| IV-02 | Info     | Missing Vesting Cliff Validation                     | Open   |
| MS-01 | Info     | Debug Statements in Production Code                  | Open   |
| MS-02 | Low      | Public Function Could Allow External Calls           | Open   |
| FS-01 | Medium   | Partial Sale Completion State Inconsistency          | Open   |
| FS-02 | High     | Protocol Fees Stuck - Never Transferred to Collector | Fixed  |

---

## Detailed Findings

### AC-01: Admin Bypass via Object Owner

**Severity:** Medium  
**Location:** `launchpad.move` lines 1381-1389

**Description:**
The `is_admin()` function allows both the configured admin address AND the object owner (if deployed as an object) to pass admin checks:

```move
fun is_admin(config: &Config, sender: address): bool {
    if (sender == config.admin_addr) { true }
    else {
        if (object::is_object(@deployment_addr)) {
            let obj = object::address_to_object<ObjectCore>(@deployment_addr);
            object::is_owner(obj, sender)  // <-- Object owner bypasses admin
        } else { false }
    }
}
```

**Impact:**
If the deployment object is transferred to a new owner, that owner immediately gains admin privileges without going through the two-step `set_pending_admin`/`accept_admin` flow. This creates a shadow admin path that bypasses intended governance.

**Proof of Concept:**

1. Contract is deployed as an object owned by Address A
2. Admin is set to Address B via proper governance
3. Address A transfers object ownership to Address C
4. Address C now has full admin privileges, bypassing all governance

**Recommendation:**
Remove the object owner fallback or require explicit opt-in:

```move
fun is_admin(config: &Config, sender: address): bool {
    sender == config.admin_addr
}
```

---

### AC-02: Single-Step Admin Transfer in Reduction Manager

**Severity:** High  
**Location:** `nft_reduction_manager.move` lines 202-208

**Description:**
Unlike the launchpad module which uses a two-step admin transfer, the reduction manager allows immediate admin transfer:

```move
public entry fun update_admin(sender: &signer, new_admin: address) acquires ProtocolFeeReductionConfig {
    let sender_addr = signer::address_of(sender);
    let config = borrow_global_mut<ProtocolFeeReductionConfig>(@deployment_addr);
    assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_REDUCTION);
    config.admin_addr = new_admin;  // <-- Immediate transfer
}
```

**Impact:**
A compromised admin key can immediately and irrevocably transfer control to an attacker. With two-step transfer, there's a window to detect and prevent malicious transfers.

**Recommendation:**
Implement pending admin pattern matching launchpad.move:

```move
struct ProtocolFeeReductionConfig has key {
    admin_addr: address,
    pending_admin_addr: Option<address>,  // Add this
    // ...
}

public entry fun set_pending_admin(sender: &signer, new_admin: address) { ... }
public entry fun accept_admin(sender: &signer) { ... }
```

---

### AC-03: No Timelock on Privileged Operations

**Severity:** Medium  
**Location:** All admin functions in both modules

**Description:**
All admin operations take effect immediately without any timelock delay. This includes:

- Protocol fee changes
- Mint enabled/disabled
- Collection settings
- Fee reduction configurations

**Impact:**
Users have no advance warning of protocol changes. A malicious or compromised admin can:

1. Instantly increase protocol fees right before a large mint
2. Disable minting mid-sale
3. Change fee reduction rules retroactively

**Recommendation:**
Implement a timelock mechanism for sensitive operations:

```move
struct PendingChange has store {
    action_type: u8,
    new_value: vector<u8>,
    execute_after: u64,  // timestamp
}
```

---

### AC-04: Creator Functions Enable Front-Running

**Severity:** Low  
**Location:** `launchpad.move` - `update_mint_fee()`, `update_mint_times()`

**Description:**
Collection creators can update mint fees and mint times at any moment, including while users have pending transactions:

```move
public entry fun update_mint_fee(
    sender: &signer,
    collection_obj: Object<Collection>,
    stage_name: String,
    new_mint_fee: u64
) acquires CollectionConfig {
    verify_collection_creator(...);
    // Immediate update, no delay
    borrow_collection_config_mut(&collection_obj).mint_fee_per_nft_by_stages.upsert(
        stage_name, new_mint_fee
    );
}
```

**Impact:**
A malicious creator could:

1. Watch mempool for incoming mint transactions
2. Front-run with a fee increase transaction
3. Cause user transactions to pay higher fees or fail

**Recommendation:**
Consider implementing a minimum notice period for fee changes, or allow fee changes only when minting is disabled.

---

### AC-05: Sale Completion Callable by Anyone

**Severity:** Info  
**Location:** `launchpad.move` line 851

**Description:**
The `check_and_complete_sale()` function has no access control - anyone can call it:

```move
public entry fun check_and_complete_sale(
    collection_obj: Object<Collection>
) acquires CollectionConfig, CollectionOwnerObjConfig {
    // No sender verification
```

**Impact:**
While the function checks conditions properly, allowing anyone to trigger it means:

1. Timing of FA creation and LP pool is not controlled by creator/admin
2. MEV bots could trigger this at strategic moments

**Note:** This may be intentional design for permissionless completion. Document if so.

---

### AR-01: Vesting Token Dust Loss Due to Rounding

**Severity:** Low  
**Location:** `vesting.move` line 166

**Description:**
When calculating tokens per NFT, integer division may leave dust:

```move
let amount_per_nft = total_pool / max_supply;
```

For example:

- `total_pool = 100,000,000,000,000,000` (10% of 1B with 9 decimals)
- `max_supply = 7` (odd number)
- `amount_per_nft = 14,285,714,285,714,285`
- Total claimable: `14,285,714,285,714,285 * 7 = 99,999,999,999,999,995`
- Lost: 5 tokens

**Impact:**
Small amounts of tokens become permanently locked in the vesting contract.

**Recommendation:**
Track remainder and distribute to last claimers, or require max_supply to be a divisor of total_pool.

---

### AR-02: Protocol Fee Reduction Rounding Favors Protocol

**Severity:** Info  
**Location:** `nft_reduction_manager.move` line 125

**Description:**

```move
original_protocol_fee - (original_protocol_fee * reduction_percentage / 100)
```

Integer division always rounds down, meaning users get slightly less reduction than advertised.

**Impact:**
For small fees, rounding error is proportionally larger. With 50% reduction on 11 fee:

- Expected: 5.5 reduction
- Actual: 5 reduction (user pays 6 instead of 5.5)

**Recommendation:**
Document this behavior or round in user's favor using ceiling division.

---

### SM-01: Potential Underflow in Refund Tracking

**Severity:** Low  
**Location:** `launchpad.move` line 1064

**Description:**

```move
collection_config.total_funds_collected -= refund_amount;
```

If there's any inconsistency between tracked funds and actual refund amounts, this will abort with underflow.

**Impact:**
While Move 2 has built-in underflow protection (abort instead of wrap), any tracking bug could lock the refund mechanism for all users.

**Recommendation:**
Add explicit check with better error message:

```move
assert!(collection_config.total_funds_collected >= refund_amount, EINSUFFICIENT_FUNDS);
collection_config.total_funds_collected -= refund_amount;
```

---

### SM-02: Sale Completion Not Atomic

**Severity:** Info  
**Location:** `launchpad.move` lines 851-1020

**Description:**
The `check_and_complete_sale` function performs multiple operations:

1. Sets `sale_completed = true`
2. Creates fungible asset
3. Mints and distributes tokens
4. Initializes vesting contracts
5. Creates DEX LP pool

If any step fails, previous state changes remain.

**Impact:**
Move's atomicity ensures all changes revert on failure, so this is informational. However, the function is complex and any unexpected revert leaves no partial state.

---

### EC-01: Free Mint Causes LP Creation Failure

**Severity:** High  
**Location:** `dex.move` lines 32-36, confirmed by test at `test_end_to_end.move` line 2003-2006

**Description:**
When mint fee is 0 (free mint), LP creation fails due to division by zero:

```move
let sqrt_token0 = math64::sqrt(amount0);  // sqrt(500M tokens) = ok
let sqrt_token1 = math64::sqrt(amount1);  // sqrt(0 MOVE) = 0
let raw_sqrt_price = ((sqrt_token1 as u128) << 80) / (sqrt_token0 as u128);  // Division by non-zero is ok
                                                                              // But amount1=0 causes other issues
```

Test confirms this:

```move
#[expected_failure(arithmetic_error, location = dex)]
fun test_free_mint_and_complete_sale(...) {
    create_public_only_collection(sender, royalty_user, 0, ...);  // mint_fee = 0
    // ... fails at LP creation
}
```

**Impact:**
Free mint collections cannot complete their sale and create tokens. This is a fundamental limitation that may or may not be intentional.

**Recommendation:**
Either:

1. Validate mint_fee > 0 at collection creation
2. Skip LP creation for free mints and distribute all tokens to vesting/dev
3. Document this limitation clearly

---

### EC-02: Initial LP Price Manipulation

**Severity:** Medium  
**Location:** `dex.move` lines 32-38

**Description:**
Initial LP price is determined by ratio of collected MOVE to FA tokens:

```move
let sqrt_token0 = math64::sqrt(amount0);  // 500M FA tokens (50%)
let sqrt_token1 = math64::sqrt(amount1);  // collected MOVE funds
```

Since FA amount is fixed (50% of 1B), price is entirely determined by collected funds.

**Attack Vector:**

1. Attacker gets early allowlist access with low mint price
2. Mints maximum allocation at low price
3. Public phase has higher price
4. When sale completes, LP price reflects weighted average
5. Attacker sells tokens at inflated LP price

**Impact:**
Early minters with discounted prices gain disproportionate profit at the expense of public minters.

**Recommendation:**
Consider using TWAP oracle pricing or minimum LP ratio requirements.

---

### IV-01: Zero Duration Vesting Allows Immediate Claim

**Severity:** Low  
**Location:** `vesting.move` lines 143-145

**Description:**

```move
if (current_time >= start_time + duration) {
    return total_amount
};
```

If `duration = 0`, all tokens vest immediately at `start_time`.

**Impact:**
Could bypass intended vesting if creator misconfigures with 0 duration.

**Recommendation:**
Add validation:

```move
assert!(duration > 0, EINVALID_DURATION);
```

---

### IV-02: Missing Vesting Cliff Validation

**Severity:** Info  
**Location:** `launchpad.move` collection creation

**Description:**
No validation that `vesting_cliff < vesting_duration`.

**Impact:**
If `cliff >= duration`, users can never claim until cliff passes, at which point all tokens are vested.

**Recommendation:**
Add validation or document intended behavior.

---

### MS-01: Debug Statements in Production Code

**Severity:** Info  
**Location:** `launchpad.move` lines 684, 1634

**Description:**

```move
debug::print(stage_idx);
debug::print(&utf8(b"Freezing transfer"));
```

**Impact:**

- Wastes gas on every execution
- Potentially leaks internal state information
- Indicates incomplete code cleanup

**Recommendation:**
Remove all debug statements before mainnet deployment:

```bash
grep -n "debug::print" move/sources/*.move
```

---

### MS-02: Public Function Could Allow External Calls

**Severity:** Low  
**Location:** `launchpad.move` line 671

**Description:**

```move
public fun mint_nft_internal(
    sender: &signer,
    collection_obj: Object<Collection>,
    amount: u64,
    reduction_nfts: vector<Object<Token>>
): vector<Object<Token>> acquires CollectionConfig, CollectionOwnerObjConfig {
```

This function is `public` rather than `public(package)`.

**Impact:**
External modules could call this function if they obtain a signer reference. While the function does proper validation (checks mint enabled, executes stage), unintended composability could emerge.

**Recommendation:**
Change to `public(package)` unless external access is explicitly intended:

```move
public(package) fun mint_nft_internal(...) { ... }
```

---

### FS-01: Partial Sale Completion State Inconsistency

**Severity:** Medium  
**Location:** `launchpad.move` lines 851-1020

**Description:**
The `check_and_complete_sale` function has a long sequence of operations. While Move ensures atomicity on failure, the success path could leave inconsistent state if the transaction runs out of gas partway through.

The function performs:

1. Borrow mutable config
2. Set `sale_completed = true`
3. Create FA object
4. Mint FA tokens
5. Extract and distribute to 4 destinations
6. Initialize NFT vesting
7. Initialize creator vesting
8. Convert coins to FA
9. Create LP pool
10. Deposit remainder
11. Update multiple config fields
12. Emit event

**Impact:**
With Move's gas model, extremely large transactions could theoretically hit gas limits, though unlikely given current limits.

**Recommendation:**
Consider breaking into multiple transactions if gas becomes a concern, using a state machine pattern.

---

### FS-02: Protocol Fees Stuck in Collection Owner - Never Transferred to Collector

**Severity:** High  
**Status:** FIXED  
**Location:** `launchpad.move` `pay_for_mint()` function

**Description:**
The contract stores a `protocol_fee_collector_addr` but never uses it. All fees (mint + protocol) are transferred to `collection_owner_addr`:

```move
// Transfer funds to the collection owner object address (acts as escrow)
let collection_owner_addr = object::object_address(&config.collection_owner_obj);
aptos_account::transfer(sender, collection_owner_addr, total_fee);  // <-- ALL fees go here

// Update total funds collected (only NFT cost, not protocol fees)
config.total_funds_collected += nft_mint_fee;  // <-- Only tracks mint fee
```

When sale completes, only `total_funds` (mint fees only) is withdrawn for LP (line 980):

```move
let move_coins = coin::withdraw<AptosCoin>(&collection_owner_signer, total_funds);
```

The protocol fees remain stuck in `collection_owner_addr` - they are NOT sent to LP (only mint fees go to LP), but they're also NOT sent to `protocol_fee_collector_addr`.

Additionally, there's an unused error constant `EONLY_ADMIN_CAN_RECOVER_FUNDS` (line 69) suggesting a recovery function was planned but never implemented.

**Impact:**

- Protocol fees are never collected by the protocol
- Protocol fees remain permanently stuck in `collection_owner_addr`
- No mechanism exists to extract protocol fees
- The `protocol_fee_collector_addr` configuration is completely unused

**Proof of Concept:**

1. User mints with 10 MOVE mint fee + 1 MOVE protocol fee = 11 MOVE paid
2. 11 MOVE goes to collection_owner_addr
3. `total_funds_collected` only increases by 10 MOVE
4. On sale completion, only 10 MOVE is withdrawn for LP
5. 1 MOVE protocol fee stays stuck in collection_owner_addr forever

**Recommendation:**
Transfer protocol fees immediately to collector during mint:

```move
if (reduced_protocol_fee > 0) {
    let config = borrow_global<Config>(@deployment_addr);
    aptos_account::transfer(sender, config.protocol_fee_collector_addr, reduced_protocol_fee);
}
// Then transfer only mint fee to collection owner for escrow
aptos_account::transfer(sender, collection_owner_addr, nft_mint_fee);
```

Alternatively, implement the planned admin recovery function to extract accumulated protocol fees.

**Resolution:**
The `pay_for_mint()` function was updated to:

1. Transfer protocol fees directly to `protocol_fee_collector_addr`
2. Transfer only mint fees to `collection_owner_addr` for escrow
3. The function now properly acquires both `CollectionConfig` and `Config`

---

## Common Aptos/Move Exploit Patterns Checklist

| Pattern                     | Status | Notes                                                          |
| --------------------------- | ------ | -------------------------------------------------------------- |
| Reentrancy                  | N/A    | Move prevents by design                                        |
| Integer Overflow            | Safe   | Move 2 has built-in checks                                     |
| Integer Underflow           | Low    | SM-01 - Could abort on tracking mismatch                       |
| Signer Mismanagement        | Medium | AC-01 - Object owner bypass                                    |
| Capability Leakage          | Safe   | ExtendRefs properly encapsulated in resources                  |
| Friend Module Abuse         | Safe   | No friend declarations in production modules                   |
| Upgrade Policy              | Review | Move.toml uses `_` for deployment_addr - verify upgrade policy |
| Under-gasing (DoS)          | Low    | Large batch reveal_nfts could exceed gas                       |
| Timestamp Manipulation      | Low    | Uses validator-controlled timestamp                            |
| Oracle Manipulation         | N/A    | No external oracles used                                       |
| Front-running               | Medium | AC-04, EC-02 - Creator/price manipulation                      |
| Fee/Payment Misrouting      | Fixed  | FS-02 - Protocol fees now transferred to collector (Fixed)     |
| State Machine Inconsistency | Medium | FS-01 - Complex sale completion logic                          |
| Division by Zero            | High   | EC-01 - Free mint with 0 funds causes LP failure               |
| Dust/Rounding Attacks       | Low    | AR-01 - Vesting dust permanently locked                        |

---

## Recommendations Summary

### Critical/High Priority

1. ~~**Fix protocol fee handling** - Transfer protocol fees to collector instead of collection owner~~ **FIXED**
2. Fix single-step admin transfer in `nft_reduction_manager.move`
3. Handle free mint (fee = 0) edge case for LP creation
4. Remove or document object owner admin bypass

### Medium Priority

5. Consider timelocks for sensitive admin operations
6. Address initial LP price manipulation vector
7. Review sale completion atomicity for gas limits

### Low Priority

8. Add explicit underflow checks with clear error messages
9. Validate vesting duration > 0
10. Change `mint_nft_internal` to `public(package)`
11. Remove debug statements

### Informational

12. Document dust loss in vesting calculations
13. Document protocol-favoring rounding in fee reductions
14. Consider restricting sale completion caller

---

## Upgrade Policy Notes

**Location:** `move/Move.toml`

```toml
[addresses]
deployment_addr='_'
```

The use of `_` placeholder for `deployment_addr` means the address is determined at deployment time. Important considerations:

1. **Object Deployment:** If deployed as an object, the upgrade policy is controlled by the object's owner
2. **Account Deployment:** If deployed to a regular account, upgrades require the account's signature
3. **Immutable Deployment:** Consider using `immutable` upgrade policy for maximum security

**Recommendation:**
Document the intended upgrade policy and consider making critical modules immutable after launch.

---

## Files Reviewed

- `move/sources/launchpad.move` (1831 lines)
- `move/sources/vesting.move` (556 lines)
- `move/sources/dex.move` (72 lines)
- `move/sources/nft_reduction_manager.move` (259 lines)
- `move/tests/test_end_to_end.move` (2067 lines)
- `move/Move.toml`

---

## Appendix: Exploit Pattern Reference

### Move-Specific Patterns Not Applicable

These common smart contract vulnerabilities are prevented by Move's design:

1. **Reentrancy** - Move's linear type system and atomic execution prevent reentrancy
2. **Integer Overflow/Underflow** - Move 2 has built-in arithmetic checks (aborts on overflow)
3. **Uninitialized Storage** - Move requires explicit initialization
4. **Delegate Call Vulnerabilities** - Not applicable to Move's module system

### Patterns Requiring Manual Review

These patterns require developer attention:

1. **Signer/Capability Misuse** - Ensure signers are properly verified
2. **Access Control** - Verify all privileged functions have proper guards
3. **Economic Attacks** - Price manipulation, MEV, flash loan equivalents
4. **Logic Errors** - State machine inconsistencies, incorrect calculations
5. **Gas/Resource Exhaustion** - Unbounded loops, large batch operations

---

_End of Security Audit Report_
