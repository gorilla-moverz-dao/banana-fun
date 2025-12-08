import * as fs from "node:fs";
import { Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";
import yaml from "js-yaml";

export interface YamlConfig {
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

export function getSigner(yamlPath: string, profile = "default"): Account {
	const pk = parsePrivateKey(yamlPath, profile);
	if (!pk) {
		console.error("Error reading private key");
		process.exit(1);
	}

	return Account.fromPrivateKey({ privateKey: new Ed25519PrivateKey(pk) });
}

export function dateToSeconds(date: Date): number {
	return Math.floor(+date / 1000);
}

export function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}
