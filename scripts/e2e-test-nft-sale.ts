/**
 * End-to-end test for NFT sale flow
 *
 * This script tests the full NFT launchpad flow:
 * 1. Create a collection with mint stages
 * 2. Mint NFTs
 * 3. Complete the sale (if threshold met)
 * 4. Test vesting claims
 *
 * Usage: bun run scripts/e2e-test-nft-sale.ts
 */

import {
  Account,
  Aptos,
  AptosConfig,
  Ed25519PrivateKey,
  Network,
} from "@aptos-labs/ts-sdk";
import type { UserTransactionResponse } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import yaml from "js-yaml";
import * as fs from "node:fs";

import { ABI as launchpadABI } from "../src/abi/nft_launchpad";
import { ABI as vestingABI } from "../src/abi/vesting";
import { MOVE_NETWORK } from "@/constants";

// ================================= Configuration =================================

const MOVE_DIR = "move/";
const MOVEMENT_CONFIG_PATH = `${MOVE_DIR}.movement/config.yaml`;

// Collection configuration for testing
const TEST_COLLECTION_CONFIG = {
  name: "E2E Test Collection",
  description: "Test collection for e2e testing of the NFT launchpad",
  uri: "https://example.com/collection.json",
  maxSupply: 10,
  placeholderUri: "https://example.com/placeholder.png",
  mintFeePerNFT: 100_000_000, // 0.1 MOVE (8 decimals)
  royaltyPercentage: 5,
  // Fungible asset config
  faSymbol: "TEST",
  faName: "Test Token",
  faIconUri: "https://example.com/icon.png",
  faProjectUri: "https://example.com/project",
  // Vesting config
  vestingCliff: 60, // 1 minute cliff
  vestingDuration: 300, // 5 minutes duration
  creatorVestingCliff: 60,
  creatorVestingDuration: 300,
};

// ================================= Helpers =================================

interface YamlConfig {
  profiles: {
    default?: {
      private_key: string;
      account?: string;
    };
    testnet?: {
      private_key: string;
      account?: string;
    };
  };
}

function parsePrivateKey(filePath: string, profile = "default"): string | undefined {
  try {
    const fileContents = fs.readFileSync(filePath, "utf8");
    const data = yaml.load(fileContents) as YamlConfig;

    if (data?.profiles?.[profile as keyof YamlConfig["profiles"]]) {
      return data.profiles[profile as keyof YamlConfig["profiles"]]?.private_key;
    }
    throw new Error("Invalid YAML structure");
  } catch (error) {
    console.error(`Error reading or parsing YAML file: ${(error as Error).message}`);
    return undefined;
  }
}

function getSigner(yamlPath: string, profile = "default"): Account {
  const pk = parsePrivateKey(yamlPath, profile);
  if (!pk) {
    console.error("Error reading private key");
    process.exit(1);
  }

  return Account.fromPrivateKey({ privateKey: new Ed25519PrivateKey(pk) });
}

function dateToSeconds(date: Date): number {
  return Math.floor(+date / 1000);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ================================= Setup Clients =================================

const config = new AptosConfig({
  network: Network.CUSTOM,
  fullnode: MOVE_NETWORK.rpcUrl,
  indexer: MOVE_NETWORK.indexerUrl,
  faucet: MOVE_NETWORK.faucetUrl,
});

const aptos = new Aptos(config);
const surfClient = createSurfClient(aptos);

// Get module address from the deployed contract (read from constants or use the signer's address)
// For testing, we'll get the module address from the ABI
const MODULE_ADDRESS = launchpadABI.address as `0x${string}`;

const launchpadClient = surfClient.useABI({ ...launchpadABI, address: MODULE_ADDRESS });
const vestingClient = surfClient.useABI({ ...vestingABI, address: MODULE_ADDRESS });

// ================================= Test Functions =================================

async function getAccountBalance(address: string): Promise<bigint> {
  const balance = await aptos.getAccountAPTAmount({ accountAddress: address });
  return BigInt(balance.toString());
}

async function fundAccount(account: Account): Promise<void> {
  if (!MOVE_NETWORK.faucetUrl) {
    console.log("No faucet available, skipping funding");
    return;
  }

  console.log(`Funding account ${account.accountAddress.toString()}...`);
  try {
    await aptos.fundAccount({
      accountAddress: account.accountAddress,
      amount: 100_000_000_000, // 1000 MOVE
    });
    console.log("Account funded successfully");
  } catch (error) {
    console.log("Faucet funding failed, continuing with existing balance...");
  }
}

interface CreateCollectionResult {
  collectionId: `0x${string}`;
  txHash: string;
}

async function createCollection(
  signer: Account,
  config: typeof TEST_COLLECTION_CONFIG
): Promise<CreateCollectionResult> {
  console.log("\n📦 Creating collection...");

  const now = dateToSeconds(new Date());
  const oneYearFromNow = now + 365 * 24 * 60 * 60;
  const saleDeadline = now + 7 * 24 * 60 * 60; // 1 week from now

  // Create a public mint stage
  const stageNames = ["Public Sale"];
  const stageTypes = [2]; // STAGE_TYPE_PUBLIC = 2
  const allowlistAddresses: (`0x${string}`[] | undefined)[] = [undefined];
  const allowlistMintLimits: (bigint[] | undefined)[] = [undefined];
  const startTimes = [BigInt(now)];
  const endTimes = [BigInt(oneYearFromNow)];
  const mintFeesPerNFT = [BigInt(config.mintFeePerNFT)];
  const mintLimitsPerAddr = [BigInt(config.maxSupply)]; // Allow minting up to max supply per user

  const response = (await launchpadClient.entry.create_collection({
    typeArguments: [],
    functionArguments: [
      config.description,
      config.name,
      config.uri,
      BigInt(config.maxSupply),
      config.placeholderUri,
      signer.accountAddress.toString() as `0x${string}`, // mint_fee_collector_addr
      signer.accountAddress.toString() as `0x${string}`, // royalty_address
      BigInt(config.royaltyPercentage), // royalty_percentage
      stageNames,
      new Uint8Array(stageTypes),
      allowlistAddresses,
      allowlistMintLimits,
      startTimes,
      endTimes,
      mintFeesPerNFT,
      mintLimitsPerAddr,
      [], // collection_settings (empty for non-soulbound)
      signer.accountAddress.toString() as `0x${string}`, // dev_wallet_addr
      BigInt(saleDeadline),
      new Uint8Array(new TextEncoder().encode(config.faSymbol)),
      new Uint8Array(new TextEncoder().encode(config.faName)),
      new Uint8Array(new TextEncoder().encode(config.faIconUri)),
      new Uint8Array(new TextEncoder().encode(config.faProjectUri)),
      BigInt(config.vestingCliff),
      BigInt(config.vestingDuration),
      signer.accountAddress.toString() as `0x${string}`, // creator_vesting_wallet_addr
      BigInt(config.creatorVestingCliff),
      BigInt(config.creatorVestingDuration),
    ],
    account: signer,
  })) as UserTransactionResponse;

  // Extract collection ID from events
  const createEvent = response.events.find((e) =>
    e.type.includes("CreateCollectionEvent")
  );

  if (!createEvent) {
    throw new Error("Collection creation event not found");
  }

  const collectionId = (createEvent.data as { collection_obj: { inner: string } }).collection_obj
    .inner as `0x${string}`;

  console.log(`✅ Collection created: ${collectionId}`);
  console.log(`   TX: ${response.hash}`);

  return { collectionId, txHash: response.hash };
}

async function mintNFT(
  signer: Account,
  collectionId: `0x${string}`,
  amount: number
): Promise<{ txHash: string; nftIds: `0x${string}`[] }> {
  console.log(`\n🎨 Minting ${amount} NFT(s)...`);

  const response = (await launchpadClient.entry.mint_nft({
    typeArguments: [],
    functionArguments: [
      collectionId,
      BigInt(amount),
      [], // No reduction NFTs
    ],
    account: signer,
  })) as UserTransactionResponse;

  // Extract NFT IDs from events
  const mintEvent = response.events.find((e) => e.type.includes("BatchMintNftsEvent"));

  const nftIds: `0x${string}`[] = [];
  if (mintEvent) {
    const nftObjs = (mintEvent.data as { nft_objs: { inner: string }[] }).nft_objs;
    for (const obj of nftObjs) {
      nftIds.push(obj.inner as `0x${string}`);
    }
  }

  console.log(`✅ Minted ${amount} NFT(s)`);
  console.log(`   TX: ${response.hash}`);
  console.log(`   NFT IDs: ${nftIds.join(", ")}`);

  return { txHash: response.hash, nftIds };
}

async function getCollectionInfo(collectionId: `0x${string}`): Promise<void> {
  console.log("\n📊 Collection Info:");

  const [collectedFunds] = await launchpadClient.view.get_collected_funds({
    typeArguments: [],
    functionArguments: [collectionId],
  });

  const [saleCompleted] = await launchpadClient.view.is_sale_completed({
    typeArguments: [],
    functionArguments: [collectionId],
  });

  const [saleDeadline] = await launchpadClient.view.get_sale_deadline({
    typeArguments: [],
    functionArguments: [collectionId],
  });

  const [creator] = await launchpadClient.view.get_creator({
    typeArguments: [],
    functionArguments: [collectionId],
  });

  console.log(`   Creator: ${creator}`);
  console.log(`   Collected Funds: ${collectedFunds} (${Number(collectedFunds) / 1e8} MOVE)`);
  console.log(`   Sale Completed: ${saleCompleted}`);
  console.log(`   Sale Deadline: ${new Date(Number(saleDeadline) * 1000).toISOString()}`);
}

async function checkAndCompleteSale(
  signer: Account,
  collectionId: `0x${string}`
): Promise<boolean> {
  console.log("\n🏁 Checking if sale can be completed...");

  const [saleCompleted] = await launchpadClient.view.is_sale_completed({
    typeArguments: [],
    functionArguments: [collectionId],
  });

  if (saleCompleted) {
    console.log("   Sale already completed!");
    return true;
  }

  try {
    const response = (await launchpadClient.entry.check_and_complete_sale({
      typeArguments: [],
      functionArguments: [collectionId],
      account: signer,
    })) as UserTransactionResponse;

    const completedEvent = response.events.find((e) =>
      e.type.includes("SaleCompletedEvent")
    );

    if (completedEvent) {
      const eventData = completedEvent.data as {
        total_funds: string;
        fa_metadata_addr: string;
        fa_total_minted: string;
      };
      console.log(`✅ Sale completed!`);
      console.log(`   TX: ${response.hash}`);
      console.log(`   Total Funds: ${eventData.total_funds}`);
      console.log(`   FA Metadata: ${eventData.fa_metadata_addr}`);
      console.log(`   FA Total Minted: ${eventData.fa_total_minted}`);
      return true;
    }
  } catch (error) {
    console.log(`   Sale cannot be completed yet: ${(error as Error).message}`);
  }

  return false;
}

async function checkVestingInfo(collectionId: `0x${string}`): Promise<void> {
  console.log("\n💰 Vesting Info:");

  try {
    const [isInitialized] = await vestingClient.view.is_vesting_initialized({
      typeArguments: [],
      functionArguments: [collectionId],
    });

    if (!isInitialized) {
      console.log("   Vesting not yet initialized (sale not completed)");
      return;
    }

    const vestingConfig = await vestingClient.view.get_vesting_config({
      typeArguments: [],
      functionArguments: [collectionId],
    });

    console.log(`   Total Pool: ${vestingConfig[0]}`);
    console.log(`   Amount Per NFT: ${vestingConfig[1]}`);
    console.log(`   Cliff: ${vestingConfig[2]}s`);
    console.log(`   Duration: ${vestingConfig[3]}s`);
    console.log(`   Start Time: ${new Date(Number(vestingConfig[4]) * 1000).toISOString()}`);

    const [remainingTokens] = await vestingClient.view.get_remaining_vesting_tokens({
      typeArguments: [],
      functionArguments: [collectionId],
    });
    console.log(`   Remaining Tokens: ${remainingTokens}`);
  } catch (error) {
    console.log(`   Error getting vesting info: ${(error as Error).message}`);
  }
}

async function claimVesting(
  signer: Account,
  collectionId: `0x${string}`,
  nftId: `0x${string}`
): Promise<void> {
  console.log(`\n🎁 Claiming vesting for NFT ${nftId}...`);

  try {
    // Check claimable amount first
    const [claimable] = await vestingClient.view.get_claimable_amount({
      typeArguments: [],
      functionArguments: [collectionId, nftId],
    });

    console.log(`   Claimable amount: ${claimable}`);

    if (BigInt(claimable.toString()) === 0n) {
      console.log("   Nothing to claim yet (cliff period not passed or already claimed)");
      return;
    }

    const response = (await vestingClient.entry.claim({
      typeArguments: [],
      functionArguments: [collectionId, nftId],
      account: signer,
    })) as UserTransactionResponse;

    console.log(`✅ Vesting claimed!`);
    console.log(`   TX: ${response.hash}`);
  } catch (error) {
    console.log(`   Claim failed: ${(error as Error).message}`);
  }
}

async function testReclaimFunds(
  signer: Account,
  collectionId: `0x${string}`,
  nftId: `0x${string}`
): Promise<void> {
  console.log(`\n🔄 Testing reclaim funds (should fail if sale threshold met)...`);

  try {
    const [canReclaim] = await launchpadClient.view.can_reclaim({
      typeArguments: [],
      functionArguments: [collectionId, signer.accountAddress.toString() as `0x${string}`],
    });

    console.log(`   Can reclaim: ${canReclaim}`);

    if (!canReclaim) {
      console.log("   Reclaim not possible (threshold met or deadline not passed)");
      return;
    }

    const response = (await launchpadClient.entry.reclaim_funds({
      typeArguments: [],
      functionArguments: [collectionId, nftId],
      account: signer,
    })) as UserTransactionResponse;

    console.log(`✅ Funds reclaimed!`);
    console.log(`   TX: ${response.hash}`);
  } catch (error) {
    console.log(`   Reclaim failed (expected): ${(error as Error).message}`);
  }
}

async function getRegisteredCollections(): Promise<void> {
  console.log("\n📋 Registered Collections:");

  try {
    const [collections] = await launchpadClient.view.get_registry({
      typeArguments: [],
      functionArguments: [],
    });

    console.log(`   Total collections with mint enabled: ${collections.length}`);
    for (const col of collections) {
      console.log(`   - ${col}`);
    }
  } catch (error) {
    console.log(`   Error: ${(error as Error).message}`);
  }
}

// ================================= Main Test Flow =================================

async function main() {
  console.log("🚀 Starting NFT Sale E2E Test\n");
  console.log(`Module Address: ${MODULE_ADDRESS}`);

  // Get signer from config
  const admin = getSigner(MOVEMENT_CONFIG_PATH, "testnet");
  console.log(`Admin Address: ${admin.accountAddress.toString()}`);

  // Check balance
  const balance = await getAccountBalance(admin.accountAddress.toString());
  console.log(`Admin Balance: ${balance} (${Number(balance) / 1e8} MOVE)`);

  if (balance < 1_000_000_000n) {
    console.log("\n⚠️  Low balance, attempting to fund from faucet...");
    await fundAccount(admin);
  }

  // Get registered collections
  await getRegisteredCollections();

  // Create a new collection
  const { collectionId } = await createCollection(admin, TEST_COLLECTION_CONFIG);

  // Wait a bit for indexer to catch up
  await sleep(2000);

  // Get collection info
  await getCollectionInfo(collectionId);

  // Mint all NFTs to meet the threshold
  console.log("\n📈 Minting NFTs to meet sale threshold...");
  const allNftIds: `0x${string}`[] = [];

  // Mint in batches to avoid transaction size limits
  const batchSize = 5;
  for (let i = 0; i < TEST_COLLECTION_CONFIG.maxSupply; i += batchSize) {
    const amount = Math.min(batchSize, TEST_COLLECTION_CONFIG.maxSupply - i);
    const { nftIds } = await mintNFT(admin, collectionId, amount);
    allNftIds.push(...nftIds);
    await sleep(1000); // Wait between mints
  }

  // Get updated collection info
  await getCollectionInfo(collectionId);

  // Note: In a real test, we would need to wait for the sale deadline to pass
  // For this e2e test, we'll attempt to complete the sale
  // This will fail if the deadline hasn't passed yet
  const saleCompleted = await checkAndCompleteSale(admin, collectionId);

  if (saleCompleted) {
    // Check vesting info
    await checkVestingInfo(collectionId);

    // Try to claim vesting for the first NFT
    if (allNftIds.length > 0) {
      await claimVesting(admin, collectionId, allNftIds[0]);
    }
  } else {
    // Test reclaim (should fail if threshold is met but deadline not passed)
    if (allNftIds.length > 0) {
      await testReclaimFunds(admin, collectionId, allNftIds[0]);
    }
  }

  // Final summary
  console.log("\n" + "=".repeat(60));
  console.log("📊 E2E Test Summary");
  console.log("=".repeat(60));
  console.log(`Collection ID: ${collectionId}`);
  console.log(`NFTs Minted: ${allNftIds.length}`);
  console.log(`Sale Completed: ${saleCompleted}`);

  // Get final balance
  const finalBalance = await getAccountBalance(admin.accountAddress.toString());
  console.log(`Final Balance: ${finalBalance} (${Number(finalBalance) / 1e8} MOVE)`);
  console.log(
    `Balance Change: ${Number(finalBalance - balance) / 1e8} MOVE`
  );

  console.log("\n✅ E2E Test Complete!");
}

main().catch((error) => {
  console.error("\n❌ E2E Test Failed:");
  console.error(error);
  process.exit(1);
});

