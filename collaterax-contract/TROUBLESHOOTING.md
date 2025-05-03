# CollateraX Contract Troubleshooting Guide

This guide provides solutions for common errors you might encounter when working with the CollateraX smart contracts.

## Common Build Errors

### 1. Missing Imports

**Error:**
```
error[E03006]: unexpected name in this position
   ┌─ ./sources/staking.move:96:29
   │
96 │         let admin_address = signer::address_of(admin);
   │                             ^^^^^^ Could not resolve the name 'signer'
```

**Solution:**
Add the missing import at the top of your file:
```move
use std::signer;
```

### 2. Incorrect Object ID Type

**Error:**
```
error[Iota E02007]: invalid object declaration
   ┌─ ./sources/asset_nft.move:30:9
   │
28 │     struct AssetNFT has key, store {
   │                         --- The 'key' ability is used to declare objects in IOTA
29 │         /// Unique identifier for the asset
30 │         id: ID,
   │         ^^  -- But found type: 'iota::object::ID'
   │         │    
   │         Invalid object 'AssetNFT'. Structs with the 'key' ability must have 'id: iota::object::UID' as their first field
```

**Solution:**
Change the ID type from `ID` to `UID` in structs with the `key` ability:
```move
// Change this:
id: ID,

// To this:
id: UID,
```

Also update your imports:
```move
// Change this:
use iota::object::{Self, Object, ID};

// To this:
use iota::object::{Self, UID, ID};
```

### 3. Missing Struct Visibility

**Error:**
```
error[E01003]: invalid modifier
   ┌─ ./sources/asset_nft.move:28:5
   │
28 │     struct AssetNFT has key, store {
   │     ^^^^^^ Invalid struct declaration. Internal struct declarations are not yet supported
   │
   = Visibility annotations are required on struct declarations from the Move 2024 edition onwards.
```

**Solution:**
Add visibility modifiers to struct declarations:
```move
// Change this:
struct AssetNFT has key, store {

// To this:
public struct AssetNFT has key, store {
```

### 4. Type Mismatches in Math Operations

**Error:**
```
error[E04007]: incompatible types
    ┌─ ./sources/staking.move:159:39
    │
157 │             let annual_ms: u64 = 365 * 24 * 60 * 60 * 1000; // milliseconds in a year
    │                            --- Found: 'u64'. It is not compatible with the other type.
158 │             let reward_rate = (pool.apy_basis_points as u128) * (stake.amount as u128) * (stake_duration_ms as u128);
    │                                                                                                                ---- Found: 'u128'. It is not compatible with the other type.
159 │             let reward = (reward_rate / (10000 * annual_ms)) as u64; // Convert basis points to percentage
    │                                       ^ Incompatible arguments to '/'
```

**Solution:**
Ensure consistent types in mathematical operations:
```move
// Change this:
let reward = (reward_rate / (10000 * annual_ms)) as u64;

// To this:
let reward = (reward_rate / (10000u128 * (annual_ms as u128))) as u64;
```

### 5. Missing Drop Ability

**Error:**
```
error[E05001]: ability constraint not satisfied
    ┌─ ./sources/staking.move:226:13
    │
 38 │         stakes: Table<address, Stake>,
    │                                ----- The type 'collaterax::staking::Stake' does not have the ability 'drop'
    ·
 48 │     struct Stake has store {
    │            ----- To satisfy the constraint, the 'drop' ability would need to be added here
    ·
226 │             table::remove(&mut pool.stakes, staker_address);
    │             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Cannot ignore values without the 'drop' ability. The value must be used
```

**Solution:**
Add the `drop` ability to the `Stake` struct:
```move
// Change this:
struct Stake has store {

// To this:
public struct Stake has store, drop {
```

## Manual Fixes for Specific Files

If the automated fix script doesn't resolve all issues, you may need to make manual changes to specific files.

### staking.move

1. Fix the reward calculation:
```move
// Change this:
let reward = (reward_rate / (10000 * annual_ms)) as u64;

// To this:
let reward = (reward_rate / (10000u128 * (annual_ms as u128))) as u64;
```

2. Add proper handling for the `Stake` struct when removing it:
```move
// If you can't add the 'drop' ability, use this pattern instead:
let Stake { amount: _, staked_at: _, last_reward_time: _, pending_rewards: _ } = table::remove(&mut pool.stakes, staker_address);
```

### governance_dao.move

1. Fix the proposal ID handling:
```move
// Change this:
let proposal_id = object::new(ctx);
table::add(&mut registry.proposals, object::id(&proposal_id), proposal);

// To this:
let proposal_id = object::new(ctx);
let proposal_id_copy = object::id(&proposal_id);
table::add(&mut registry.proposals, proposal_id_copy, proposal);
```

## Running the Fix Script

The `fix_contracts.sh` script automates many of these fixes. Run it from the contract directory:

```bash
./fix_contracts.sh
```

After running the script, try building the contracts again:

```bash
iota move build
```

If you still encounter errors, refer to the specific solutions in this guide.

## Getting Help

If you continue to experience issues after trying these solutions, consider:

1. Checking the [IOTA Move documentation](https://wiki.iota.org/shimmer/smart-contracts/guide/move/overview/)
2. Reviewing the [Move language reference](https://move-language.github.io/move/)
3. Posting your question in the [IOTA Discord](https://discord.iota.org/) or [Stack Overflow](https://stackoverflow.com/questions/tagged/iota)

## Contributing Fixes

If you discover additional common issues and solutions, please consider contributing them back to the project by:

1. Updating this troubleshooting guide
2. Enhancing the fix script
3. Submitting a pull request with your improvements
