import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
	return twMerge(clsx(inputs));
}

/**
 * Convert APT to oapt (smallest unit, integer)
 */
export function aptToOapt(apt: string | number): number {
	return Math.round(Number(apt) * 1e8);
}

/**
 * Convert oapt (smallest unit) to APT
 */
export function oaptToApt(oapt: string | number): number {
	return Number(oapt) / 1e8;
}

/**
 * Normalizes a hex string to ensure it has the correct format (0x + 64 hex characters).
 * Pads with leading zeros if necessary.
 */
export const normalizeHexAddress = (hex: string): string => {
	const hexPart = hex.slice(2);
	const normalizedHex = hexPart.padStart(64, "0");
	return `0x${normalizedHex}`;
};

/**
 * Converts a full address to a short address.
 * @param address - The full address.
 * @returns The short address.
 */
export function toShortAddress(address: string): string {
	return `${address.slice(0, 6)}...${address.slice(-4)}`;
}
