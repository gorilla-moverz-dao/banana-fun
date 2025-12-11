# Banana Fun - Project Summary

## Demo

https://banana-fun.gorilla-moverz.xyz/

## Overview

**Banana Fun** is an NFT-backed token launchpad platform that combines NFT sales, token generation, and liquidity pool creation into a single streamlined mechanism. The platform enables projects to launch NFT collections while simultaneously bootstrapping token liquidity on decentralized exchanges.

## Key Features

### 1. Conditional Launch Mechanism

- NFT collections are minted with a fixed maximum supply and hard cap
- If the threshold is reached before deadline: automatically creates liquidity pool on DEX and enables token claims
- If threshold not met: buyers can refund by burning NFTs (safe presale mechanism)

### 2. Multi-Stage Minting

- Supports multiple mint stages with different pricing, whitelists, and time windows
- Whitelist tiers for pre-mint, public mint, and discounted rounds
- Sybil protection via Discord roles, NFT ownership, or permissioned wallet lists

### 3. Instant-Reveal NFTs

- NFTs reveal immediately upon minting
- Enables quality-based trading and community evaluation from launch

### 4. Token Distribution

When a sale completes successfully (all NFTs minted), the platform automatically:

- **Mints total token supply**: A fixed total supply of fungible tokens is created for the collection
- **Distributes to liquidity pool**: A portion is allocated for creating a DEX liquidity pool on Yuzuswap
- **Allocates to NFT holder vesting**: A portion is locked in the vesting contract, distributed proportionally to NFT holders based on their ownership
- **Sends to dev wallet**: A portion is immediately transferred to the project's development wallet (can be used for Airdrops, ...)
- **Allocates to creator vesting**: A portion is locked in the creator vesting contract for the team

All distributions happen atomically when the sale completes. NFT holders can claim their vested tokens over time, while the liquidity pool is created immediately to enable trading.

### 5. Vesting System

The platform implements a dual vesting system for token distribution:

**NFT Holder Vesting:**

- Tokens are allocated per NFT owned (typically 10% of total token supply)
- Linear vesting schedule with configurable cliff period and duration
- NFT holders claim vested tokens by presenting their NFT
- Each NFT has its own vesting allocation that vests independently
- Prevents early dumping and stabilizes token price

**Creator/Team Vesting:**

- Separate vesting pool for project creators and team (typically 30% of total supply)
- Single beneficiary address receives the entire creator vesting pool
- Same linear vesting mechanism with configurable cliff and duration
- Beneficiary can claim vested tokens directly (must be the designated address)
- Ensures long-term alignment between team and project success

Both vesting systems are automatically initialized when a sale completes successfully, with tokens locked in secure vaults until they vest.

## Core Architecture

### Backend

**Move/Aptos Smart Contracts:**

- **Smart Contracts**: Written in Move, deployed on Aptos blockchain
- **Launchpad Module** (`launchpad.move`): Manages NFT collections, mint stages, whitelists, and conditional token distribution
- **DEX Integration** (`dex.move`): Integrates with Yuzuswap for automatic liquidity pool creation
- **Vesting Module**: Handles token vesting and delayed claims
- **NFT Reduction Manager**: Manages NFT-based token reduction mechanics
- **Testing**: Movement SDK for testing

**Convex Backend Service:**

- **Database**: Convex for caching blockchain data and improving frontend performance
- **Real-time Sync**: Automatic synchronization of collection state from blockchain every minute
- **Data Caching**: Stores collection metadata, mint stages, sale status, supply, and funds collected
- **Query API**: Provides efficient queries for frontend without direct blockchain calls

### Frontend

- **Framework**: React 19 with TanStack Router for file-based routing
- **Language**: TypeScript
- **Build Tool**: Vite
- **State Management**: TanStack Query for server state
- **UI Components**: Shadcn UI components with Tailwind CSS
- **Wallet Integration**: Aptos wallet adapter for blockchain interactions
- **GraphQL**: Code generation for type-safe API queries
- **Code Quality**: Biome for linting and formatting

## Project Structure

- `/move/` - Move smart contracts and tests
- `/src/` - React frontend application
- `/convex/` - Convex backend functions, schema, and sync actions
- `/docs/` - Project documentation
- `/scripts/` - Build and deployment scripts

## Development Status

Active development with focus on:

- NFT launchpad functionality
- DEX integration for liquidity pools
- Multi-stage minting with whitelists
- Frontend UI for collection browsing and minting
- Convex integration for real-time data synchronization
- Vesting system for NFT holders and team members
