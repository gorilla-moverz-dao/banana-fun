# Banana Fun - Project Summary

## Demo

https://banana-fun.gorilla-moverz.xyz/

## Overview

**Banana Fun** is an NFT-backed token launchpad platform that combines NFT sales, token generation, and liquidity pool creation into a single streamlined mechanism. The platform enables projects to launch NFT collections while simultaneously bootstrapping token liquidity on decentralized exchanges.

## Core Architecture

### Backend (Move/Aptos)

- **Smart Contracts**: Written in Move, deployed on Aptos blockchain
- **Launchpad Module** (`launchpad.move`): Manages NFT collections, mint stages, whitelists, and conditional token distribution
- **DEX Integration** (`dex.move`): Integrates with Yuzuswap for automatic liquidity pool creation
- **Vesting Module**: Handles token vesting and delayed claims
- **NFT Reduction Manager**: Manages NFT-based token reduction mechanics

### Frontend (React/TypeScript)

- **Framework**: React 19 with TanStack Router for file-based routing
- **State Management**: TanStack Query for server state
- **UI Components**: Shadcn UI components with Tailwind CSS
- **Wallet Integration**: Aptos wallet adapter for blockchain interactions
- **GraphQL**: Code generation for type-safe API queries

### Backend (Convex)

- **Database**: Convex for caching blockchain data and improving frontend performance
- **Real-time Sync**: Automatic synchronization of collection state from blockchain every minute
- **Data Caching**: Stores collection metadata, mint stages, sale status, supply, and funds collected
- **Query API**: Provides efficient queries for frontend without direct blockchain calls

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

- Participants can claim tokens proportional to their NFT purchases
- Optional vesting/delayed claims to stabilize early liquidity
- NFT-based reduction mechanics for token allocation

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

## Technology Stack

**Backend:**

- Move (Movement/Aptos blockchain)
- Convex (real-time database and sync service)
- Yuzuswap DEX integration
- Movement SDK for testing

**Frontend:**

- React 19
- TypeScript
- TanStack Router
- TanStack Query
- Tailwind CSS
- Shadcn UI
- Vite
- Biome (linting/formatting)

## Project Structure

- `/move/` - Move smart contracts and tests
- `/src/` - React frontend application
- `/convex/` - Convex backend functions, schema, and sync actions
- `/docs/` - Project documentation
- `/scripts/` - Build and deployment scripts

## Convex Integration & Data Sync

The platform uses Convex as a backend service to cache blockchain data and provide efficient queries to the frontend:

**Automatic Synchronization:**

- Cron job runs every minute to sync collection data from the blockchain
- Queries blockchain state for: current supply, owner count, funds collected, sale status, and mint stages
- Updates Convex database with latest on-chain information
- Reduces frontend blockchain queries and improves performance

**Data Cached:**

- Collection metadata and configuration
- Real-time mint stages with pricing and timing
- Sale completion status and deadlines
- Token distribution amounts (LP, vesting, dev wallet, creator vesting)
- Vesting configuration (cliff periods and durations)

**Frontend Integration:**

- React components use Convex React Client for real-time data queries
- Automatic reactivity when blockchain data updates
- Type-safe queries with generated TypeScript types
- Efficient data fetching without direct blockchain calls

## Development Status

Active development with focus on:

- NFT launchpad functionality
- DEX integration for liquidity pools
- Multi-stage minting with whitelists
- Frontend UI for collection browsing and minting
- Convex integration for real-time data synchronization
- Vesting system for NFT holders and team members
