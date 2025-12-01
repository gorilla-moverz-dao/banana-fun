import { promises as fs } from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import axios from "axios";
import { LAUNCHPAD_MODULE_ADDRESS, MOVE_NETWORK } from "../src/constants";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function getABI(address: string, moduleName: string) {
  try {
    const response = await axios.get(`${MOVE_NETWORK.rpcUrl}/accounts/${address}/module/${moduleName}`);
    const abi = response.data.abi;

    const content = `export const ABI = ${JSON.stringify(abi)} as const`;

    await fs.writeFile(path.join(__dirname, "..", "src", "abi", `${moduleName}.ts`), content);

    console.log(`ABI for ${moduleName} has been written successfully.`);
  } catch (error) {
    console.error(`Error fetching ABI for ${moduleName}:`, error);
  }
}

async function main() {
  await getABI("0x1", "coin");
  await getABI(LAUNCHPAD_MODULE_ADDRESS, "nft_launchpad");
}

main().catch(console.error);
