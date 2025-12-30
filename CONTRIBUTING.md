# Contributing to Banana Fun

This guide covers everything you need to set up and run the Banana Fun project locally.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v18+)
- **Bun** (preferred) or npm/yarn - [Install Bun](https://bun.sh/)
- **Movement CLI** - For Move smart contract development
- **Git** - For version control

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/gorilla-moverz-dao/banana-fun.git
cd banana-fun
```

### 2. Install Dependencies

```bash
bun install
```

## Environment Setup

### Environment Variables

Create a `.env.local` file in the project root:

```bash
# Network configuration (TESTNET or MAINNET)
VITE_NETWORK=TESTNET

# Convex URL (automatically set when running `bunx convex dev`)
VITE_CONVEX_URL=https://your-deployment.convex.cloud
```

## Convex Database Setup

Convex is used as the backend database for caching blockchain data and improving frontend performance. Follow these steps to set up Convex:

### 1. Create a Convex Account

1. Go to [convex.dev](https://www.convex.dev/) and sign up for a free account
2. Create a new project for Banana Fun

### 2. Initialize Convex (First Time Setup)

If this is a fresh setup without existing Convex configuration:

```bash
bunx convex init
```

This will:

- Create a new Convex project (or link to existing)
- Generate the `convex/_generated/` directory
- Set up your local environment

### 3. Deploy Convex Functions

For development (with hot-reload):

```bash
bunx convex dev
```

This command will:

- Deploy your Convex functions
- Watch for changes and automatically redeploy
- Output the `VITE_CONVEX_URL` to use (automatically added to `.env.local`)

For production deployment:

```bash
bunx convex deploy
```

### 4. Convex Schema

The database schema is defined in `convex/schema.ts` and includes:

- **collections** - NFT collection data synced from blockchain
- **mintStages** - Mint stage configurations per collection
- **nftRevealItems** - Metadata for NFT reveals

### 5. Convex Functions

Key Convex functions are located in:

- `convex/collections.ts` - Collection queries
- `convex/collectionSyncActions.ts` - Blockchain sync actions
- `convex/reveal.ts` - NFT reveal queries
- `convex/revealActions.ts` - NFT reveal actions
- `convex/crons.ts` - Scheduled sync jobs

## Running the Application

### Development Mode

Start all services (frontend, GraphQL codegen, and Convex) concurrently:

```bash
bun run dev
```

This runs:

- Vite dev server on `http://localhost:3000`
- GraphQL codegen in watch mode
- Convex dev server

### Individual Services

If you prefer to run services separately:

```bash
# Frontend only
bunx vite --port 3000

# GraphQL codegen
bun run graphql-codegen:watch

# Convex dev
bunx convex dev
```

## Move Smart Contracts

### Project Structure

```
move/
├── Move.toml          # Package configuration
├── sources/           # Contract source files
│   ├── launchpad.move
│   ├── dex.move
│   ├── vesting.move
│   └── nft_reduction_manager.move
├── tests/             # Contract tests
└── deps/              # Local dependencies (Yuzuswap)
```

### Running Tests

```bash
bun run move:test
```

Or directly:

```bash
cd move && movement move test --dev
```

### Deploying Contracts

```bash
bun run move:deploy
```

This compiles and publishes the contracts to testnet, then regenerates the ABI files.

### Building ABI

After contract changes, regenerate TypeScript ABIs:

```bash
bun run build-abi
```

## Code Quality

### Linting

```bash
bun run lint
```

### Formatting

```bash
bun run format
```

### Full Check

```bash
bun run check
```

## Building for Production

```bash
bun run build
```

This runs linting, builds the Vite app, and type-checks with TypeScript.

## Testing

### Run Tests

```bash
bun run test
```

### E2E NFT Sale Test

```bash
bun run e2e:nft-sale
```

## Project Structure

```
banana-fun/
├── src/                    # Frontend React application
│   ├── components/         # React components
│   ├── hooks/             # Custom React hooks
│   ├── lib/               # Utility libraries
│   ├── routes/            # TanStack Router pages
│   ├── graphql/           # Generated GraphQL types
│   ├── abi/               # Generated Move ABIs
│   └── providers/         # Context providers
├── convex/                # Convex backend
│   ├── schema.ts          # Database schema
│   ├── collections.ts     # Collection queries
│   └── *.ts               # Other backend functions
├── move/                  # Move smart contracts
│   ├── sources/           # Contract source files
│   └── tests/             # Contract tests
├── public/                # Static assets
├── scripts/               # Build and utility scripts
└── docs/                  # Documentation
```

## Useful Commands Reference

| Command               | Description                     |
| --------------------- | ------------------------------- |
| `bun run dev`         | Start all development services  |
| `bun run build`       | Build for production            |
| `bun run test`        | Run tests                       |
| `bun run lint`        | Run linter                      |
| `bun run format`      | Format code                     |
| `bun run move:test`   | Run Move contract tests         |
| `bun run move:deploy` | Deploy Move contracts           |
| `bun run build-abi`   | Regenerate ABIs from contracts  |
| `bunx convex dev`     | Start Convex development server |
| `bunx convex deploy`  | Deploy Convex to production     |

## Troubleshooting

### Convex URL Not Set

If you see the warning "VITE_CONVEX_URL is not set", make sure:

1. Convex dev is running (`bunx convex dev`)
2. The URL is in your `.env.local` file

### Move Tests Failing

Ensure you have the Movement CLI installed and are in the correct directory:

```bash
cd move
movement move test --dev
```

### GraphQL Codegen Errors

The codegen connects to the Movement testnet indexer. Ensure you have network access and run:

```bash
bun run graphql-codegen
```

## Contributing Guidelines

1. Create a feature branch from `main`
2. Make your changes
3. Run `bun run check` to ensure code quality
4. Run tests with `bun run test`
5. Submit a pull request

## Need Help?

- Check the [documentation](./docs/)
- Review the [README](./README.md) for project overview
- Open an issue for bugs or feature requests
