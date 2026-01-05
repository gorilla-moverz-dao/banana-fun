/**
 * End-to-end test for NFT sale flow
 *
 * This script tests the full NFT launchpad flow:
 * 1. Create a collection with mint stages
 * 2. Upload reveal data to Convex
 * 3. Mint NFTs (with automatic reveal)
 * 4. Complete the sale (if threshold met)
 * 5. Test vesting claims
 *
 * Usage: bun run scripts/e2e-test-nft-sale.ts
 */

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

// Load .env.local file manually (for tsx compatibility)
const envPath = join(process.cwd(), ".env.local");
if (existsSync(envPath)) {
	const envContent = readFileSync(envPath, "utf-8");
	for (const line of envContent.split("\n")) {
		const trimmed = line.trim();
		if (trimmed && !trimmed.startsWith("#")) {
			const [key, ...valueParts] = trimmed.split("=");
			const value = valueParts.join("=").replace(/^["']|["']$/g, "");
			if (key && !process.env[key]) {
				process.env[key] = value;
			}
		}
	}
}

import { Account, type UserTransactionResponse } from "@aptos-labs/ts-sdk";
import { ConvexHttpClient } from "convex/browser";
import { LAUNCHPAD_MODULE_ADDRESS, MOVE_NETWORK } from "@/constants";
import { aptos, launchpadClient, vestingClient } from "@/lib/aptos";
import { normalizeHexAddress } from "@/lib/utils";
import { api } from "../convex/_generated/api";
import type { Doc } from "../convex/_generated/dataModel";
import { dateToSeconds, getSigner, sleep } from "./helper";

// ================================= Convex Client =================================

const CONVEX_URL = process.env.VITE_CONVEX_URL || process.env.CONVEX_URL;
if (!CONVEX_URL) {
	console.warn("⚠️  CONVEX_URL not set. Reveal data upload will be skipped.");
	throw new Error("CONVEX_URL not set");
}
const convex = CONVEX_URL ? new ConvexHttpClient(CONVEX_URL) : null;

// ================================= Configuration =================================

const MOVE_DIR = "move/";
const MOVEMENT_CONFIG_PATH = `${MOVE_DIR}.movement/config.yaml`;

// Collection configuration for testing
const TEST_COLLECTION_CONFIG = {
	name: "BF Collection V2",
	description: "BF Collection for testing the NFT launchpad",
	uri: "https://banana-fun.gorilla-moverz.xyz/favicon.png",
	maxSupply: 50,
	placeholderUri: "https://banana-fun.gorilla-moverz.xyz/favicon.png",
	mintFeePerNFT: 100_000_000, // 0.1 MOVE (8 decimals)
	royaltyPercentage: 5,
	// Fungible asset config
	faSymbol: "BFV2_",
	faName: "BFV2 Token",
	faIconUri: "https://banana-fun.gorilla-moverz.xyz/favicon.png",
	faProjectUri: "https://banana-fun.gorilla-moverz.xyz",
	// Vesting config
	vestingCliff: 60, // 1 minute cliff
	vestingDuration: 3 * 24 * 60 * 60, // 24 hours duration
	creatorVestingCliff: 60,
	creatorVestingDuration: 3 * 24 * 60 * 60,
};

// ================================= Reveal Data Functions =================================

interface RevealItem {
	name: string;
	description: string;
	uri: string;
	traits: { trait_type: string; value: string }[];
}

interface MetadataJson {
	name: string;
	description: string;
	image: string;
	attributes: { trait_type: string; value: string }[];
}

const METADATA_DIR = "test-collection/metadata";

/**
 * Load reveal data from JSON files in test-collection/metadata
 */
function loadRevealDataFromFiles(maxSupply: number): RevealItem[] {
	const files = readdirSync(METADATA_DIR)
		.filter((f) => f.endsWith(".json"))
		.sort((a, b) => {
			// Sort numerically by filename (1.json, 2.json, ..., 50.json)
			const numA = Number.parseInt(a.replace(".json", ""), 10);
			const numB = Number.parseInt(b.replace(".json", ""), 10);
			return numA - numB;
		})
		.slice(0, maxSupply);

	console.log(`📂 Loading ${files.length} metadata files from ${METADATA_DIR}...`);

	return files.map((file) => {
		const filePath = join(METADATA_DIR, file);
		const content = readFileSync(filePath, "utf-8");
		const metadata: MetadataJson = JSON.parse(content);

		return {
			name: metadata.name,
			description: metadata.description,
			uri: metadata.image,
			traits: metadata.attributes,
		};
	});
}

/**
 * Upload reveal data to Convex
 */
async function uploadRevealData(collectionId: string, items: RevealItem[]): Promise<boolean> {
	if (!convex) {
		console.log("⚠️  Convex client not initialized, skipping reveal data upload");
		return false;
	}

	console.log(`\n📤 Uploading ${items.length} reveal items to Convex...`);

	try {
		const result = await convex.action(api.revealActions.uploadRevealData, {
			collectionId,
			items,
		});
		console.log(`✅ Uploaded ${result.inserted} reveal items`);
		return true;
	} catch (error) {
		console.error("❌ Failed to upload reveal data:", error);
		return false;
	}
}

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
	} catch (_error) {
		console.log("Faucet funding failed, continuing with existing balance...");
	}
}

/**
 * Create and fund multiple test accounts
 */
async function createAndFundTestAccounts(count: number): Promise<Account[]> {
	console.log(`\n🔑 Creating and funding ${count} test accounts...`);
	const accounts: Account[] = [];

	for (let i = 0; i < count; i++) {
		const account = Account.generate();
		console.log(`   Account ${i + 1}: ${account.accountAddress.toString()}`);

		// Fund the account
		await fundAccount(account);
		await sleep(2000); // Wait for faucet rate limiting

		accounts.push(account);
	}

	console.log(`✅ Created and funded ${accounts.length} test accounts`);
	return accounts;
}

type ConvexCollectionData = Omit<Doc<"collections">, "_id" | "_creationTime">;

interface CreateCollectionResult {
	collectionId: `0x${string}`;
	txHash: string;
	convexData: ConvexCollectionData;
}

async function createCollection(
	signer: Account,
	config: typeof TEST_COLLECTION_CONFIG,
): Promise<CreateCollectionResult> {
	console.log("\n📦 Creating collection...");

	const now = dateToSeconds(new Date());
	const saleDeadline = now + 7 * 24 * 60 * 60; // 1 week from now
	// const saleDeadline = now + 60 * 60; // 60 seconds from now

	// Create a public mint stage
	const stageNames = ["Public Sale"];
	const stageTypes = [2]; // STAGE_TYPE_PUBLIC = 2
	const allowlistAddresses: (`0x${string}`[] | undefined)[] = [undefined];
	const allowlistMintLimits: (bigint[] | undefined)[] = [undefined];
	const startTimes = [BigInt(now)];
	const endTimes = [BigInt(saleDeadline)];
	const mintFeesPerNFT = [BigInt(config.mintFeePerNFT)];
	const mintLimitsPerAddr = [BigInt(3)]; // Allow minting up to max supply per user

	const response = (await launchpadClient.entry.create_collection({
		typeArguments: [],
		functionArguments: [
			config.description,
			config.name,
			config.uri,
			BigInt(config.maxSupply),
			config.placeholderUri,
			signer.accountAddress.toString(), // royalty_address
			BigInt(config.royaltyPercentage), // royalty_percentage
			stageNames,
			stageTypes,
			allowlistAddresses,
			allowlistMintLimits,
			startTimes,
			endTimes,
			mintFeesPerNFT,
			mintLimitsPerAddr,
			[], // collection_settings (empty for non-soulbound)
			signer.accountAddress.toString(), // dev_wallet_addr
			BigInt(saleDeadline),
			config.faSymbol,
			config.faName,
			config.faIconUri,
			config.faProjectUri,
			BigInt(config.vestingCliff),
			BigInt(config.vestingDuration),
			"0x96d8b30de5924bcce4a9aa3bd0593ded1c87067638eb9af1ee291be5c1e012b4", // creator_vesting_wallet_addr
			BigInt(config.creatorVestingCliff),
			BigInt(config.creatorVestingDuration),
		],
		account: signer,
	})) as UserTransactionResponse;

	// Extract collection ID from events
	const createEvent = response.events.find((e) => e.type.includes("CreateCollectionEvent"));

	if (!createEvent) {
		throw new Error("Collection creation event not found");
	}

	const collectionId = normalizeHexAddress(
		(createEvent.data as { collection_obj: { inner: string } }).collection_obj.inner,
	) as `0x${string}`;

	console.log(`✅ Collection created: ${collectionId}`);
	console.log(`   TX: ${response.hash}`);

	// Build Convex collection data for database import
	const convexData: ConvexCollectionData = {
		collectionId,
		collectionName: config.name,
		createdAt: now,
		creatorAddress: signer.accountAddress.toString(),
		creatorVestingCliff: config.creatorVestingCliff,
		creatorVestingDuration: config.creatorVestingDuration,
		creatorVestingWalletAddress: signer.accountAddress.toString(),
		currentSupply: 0,
		description: config.description,
		devWalletAddress: signer.accountAddress.toString(),
		faIconUri: config.faIconUri,
		faName: config.faName,
		faProjectUri: config.faProjectUri,
		faSymbol: config.faSymbol,
		maxSupply: config.maxSupply,
		mintEnabled: true,
		ownerCount: 0,
		placeholderUri: config.placeholderUri,
		royaltyAddress: signer.accountAddress.toString(),
		royaltyPercentage: config.royaltyPercentage,
		saleCompleted: false,
		saleDeadline,
		totalFundsCollected: 0,
		updatedAt: Date.now(),
		uri: config.uri,
		vestingCliff: config.vestingCliff,
		vestingDuration: config.vestingDuration,
	};

	return { collectionId, txHash: response.hash, convexData };
}

async function mintNFT(
	signer: Account,
	collectionId: `0x${string}`,
	amount: number,
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

async function checkAndCompleteSale(signer: Account, collectionId: `0x${string}`): Promise<boolean> {
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

		const completedEvent = response.events.find((e) => e.type.includes("SaleCompletedEvent"));

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

async function claimVesting(signer: Account, collectionId: `0x${string}`, nftId: `0x${string}`): Promise<void> {
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

async function testReclaimFunds(signer: Account, collectionId: `0x${string}`, nftId: `0x${string}`): Promise<void> {
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

async function getRegisteredCollections(): Promise<`0x${string}`[]> {
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

		return collections.map((col) => col.inner as `0x${string}`);
	} catch (error) {
		console.log(`   Error: ${(error as Error).message}`);
		throw error;
	}
}

// ================================= Main Test Flow =================================

async function main() {
	console.log("🚀 Starting NFT Sale E2E Test\n");
	console.log(`Module Address: ${LAUNCHPAD_MODULE_ADDRESS}`);

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
	const collections = await getRegisteredCollections();
	const numberOfCollections = collections.length;

	// Create a new collection
	const config = {
		...TEST_COLLECTION_CONFIG,
		name: `${TEST_COLLECTION_CONFIG.name} ${numberOfCollections + 1}`,
		faSymbol: `${TEST_COLLECTION_CONFIG.faSymbol}${numberOfCollections + 1}`,
		faName: `${TEST_COLLECTION_CONFIG.faName} ${numberOfCollections + 1}`,
	};

	const { collectionId, convexData } = await createCollection(admin, config);

	// Wait a bit for indexer to catch up
	await sleep(2000);

	// Load and upload reveal data from metadata files
	const revealData = loadRevealDataFromFiles(config.maxSupply);
	const revealDataUploaded = await uploadRevealData(collectionId, revealData);

	// Get collection info
	await getCollectionInfo(collectionId);

	// Mint all NFTs to meet the threshold
	console.log("\n📈 Minting NFTs to meet sale threshold...");
	const allNftIds: `0x${string}`[] = [];
	let totalReveals = 0;

	// Configuration for minting
	const totalNftsToMint = 45; // Total NFTs to mint across all accounts
	const nftsPerAccount = 3; // Max NFTs per account (mint limit)
	const accountsNeeded = Math.ceil(totalNftsToMint / nftsPerAccount);

	// Create and fund test accounts (we need accountsNeeded - 1 because admin is the first account)
	const testAccounts = await createAndFundTestAccounts(accountsNeeded - 1);
	const allMinters = [admin, ...testAccounts];

	console.log(
		`\n🎯 Will mint ${totalNftsToMint} NFTs using ${allMinters.length} accounts (${nftsPerAccount} per account max)`,
	);

	// Run multiple minters in parallel
	const parallelMinters = 3; // Number of minters to run simultaneously
	const minterBatches: (typeof allMinters)[] = [];

	// Split minters into batches for parallel execution
	for (let i = 0; i < allMinters.length; i += parallelMinters) {
		minterBatches.push(allMinters.slice(i, i + parallelMinters));
	}

	// Helper function for a single minter to mint their NFTs
	const mintForAccount = async (
		minter: (typeof allMinters)[0],
		mintsForThisAccount: number,
		minterIndex: number,
	): Promise<{ nftIds: `0x${string}`[]; reveals: number }> => {
		const nftIds: `0x${string}`[] = [];
		let reveals = 0;

		console.log(
			`\n👤 [Minter ${minterIndex}] Starting ${mintsForThisAccount} mint(s) with account: ${minter.accountAddress.toString()}`,
		);

		for (let j = 0; j < mintsForThisAccount; j++) {
			// Add random delay between mints (except before the first mint of this minter)
			if (j > 0) {
				const waitTime = Math.floor(Math.random() * 5) + 1; // 1-5 seconds
				console.log(`   [Minter ${minterIndex}] ⏳ Waiting ${waitTime}s before next mint...`);
				await sleep(waitTime * 1000);
			}

			try {
				const result = await mintNFT(minter, collectionId, 1);
				nftIds.push(...result.nftIds);
				console.log(`   [Minter ${minterIndex}] ✅ Minted NFT ${j + 1}/${mintsForThisAccount}`);

				// Trigger reveal via Convex afterMint action (if reveal data was uploaded)
				if (convex && revealDataUploaded && result.nftIds.length > 0) {
					try {
						const afterMintResult = await convex.action(api.collectionSyncActions.afterMint, {
							collectionId,
							nftTokenIds: result.nftIds,
						});
						const successfulReveals = afterMintResult.reveals.filter((r) => r.success).length;
						reveals += successfulReveals;
						console.log(`   [Minter ${minterIndex}] Reveals: ${successfulReveals}/${result.nftIds.length} successful`);
					} catch (error) {
						console.warn(`   [Minter ${minterIndex}] ⚠️  afterMint failed:`, error);
					}
				}
			} catch (error) {
				console.error(`   [Minter ${minterIndex}] ❌ Mint failed:`, error);
			}
		}

		return { nftIds, reveals };
	};

	// Process minter batches - each batch runs in parallel
	let nftsMinted = 0;
	for (let batchIndex = 0; batchIndex < minterBatches.length; batchIndex++) {
		const batch = minterBatches[batchIndex];
		const remainingToMint = totalNftsToMint - nftsMinted;

		if (remainingToMint <= 0) break;

		console.log(`\n🚀 Starting batch ${batchIndex + 1}/${minterBatches.length} with ${batch.length} parallel minters`);

		// Calculate how many NFTs each minter in this batch should mint
		const mintPromises = batch.map((minter, indexInBatch) => {
			const globalMinterIndex = batchIndex * parallelMinters + indexInBatch;
			const nftsAlreadyAssigned = globalMinterIndex * nftsPerAccount;
			const nftsRemainingForThisMinter = Math.min(nftsPerAccount, totalNftsToMint - nftsAlreadyAssigned);

			if (nftsRemainingForThisMinter <= 0) {
				return Promise.resolve({ nftIds: [] as `0x${string}`[], reveals: 0 });
			}

			return mintForAccount(minter, nftsRemainingForThisMinter, globalMinterIndex + 1);
		});

		// Wait for all minters in this batch to complete
		const batchResults = await Promise.all(mintPromises);

		// Collect results
		for (const result of batchResults) {
			allNftIds.push(...result.nftIds);
			totalReveals += result.reveals;
			nftsMinted += result.nftIds.length;
		}

		console.log(`\n✅ Batch ${batchIndex + 1} complete. Total minted so far: ${nftsMinted}/${totalNftsToMint}`);
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
	console.log(`\n${"=".repeat(60)}`);
	console.log("📊 E2E Test Summary");
	console.log("=".repeat(60));
	console.log(`Collection ID: ${collectionId}`);
	console.log(`NFTs Minted: ${allNftIds.length}`);
	console.log(`Reveal Data Uploaded: ${revealDataUploaded}`);
	console.log(`NFTs Revealed: ${totalReveals}`);
	console.log(`Sale Completed: ${saleCompleted}`);

	// Get final balance
	const finalBalance = await getAccountBalance(admin.accountAddress.toString());
	console.log(`Final Balance: ${finalBalance} (${Number(finalBalance) / 1e8} MOVE)`);
	console.log(`Balance Change: ${Number(finalBalance - balance) / 1e8} MOVE`);

	// Update convex data with final state
	const finalConvexData = {
		...convexData,
		currentSupply: allNftIds.length,
		ownerCount: 1, // Admin owns all NFTs
		totalFundsCollected: allNftIds.length * TEST_COLLECTION_CONFIG.mintFeePerNFT,
		saleCompleted,
		updatedAt: Date.now(),
	};

	// Output compact JSON for easy copy-paste into Convex
	console.log("\n📋");
	console.log(JSON.stringify(finalConvexData));

	console.log("\n✅ E2E Test Complete!");
}

main().catch((error) => {
	console.error("\n❌ E2E Test Failed:");
	console.error(error);
	process.exit(1);
});
