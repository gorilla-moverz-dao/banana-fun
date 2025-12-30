import { useEffect, useState } from "react";

const STORAGE_KEY = "banana-fun-device-id";

/**
 * Generate a UUID v4
 */
function generateUUID(): string {
	return crypto.randomUUID();
}

/**
 * Hook to get a stable device ID from localStorage.
 * Creates one if it doesn't exist.
 */
export function useDeviceId(): string | null {
	const [deviceId, setDeviceId] = useState<string | null>(null);

	useEffect(() => {
		let id = localStorage.getItem(STORAGE_KEY);
		if (!id) {
			id = generateUUID();
			localStorage.setItem(STORAGE_KEY, id);
		}
		setDeviceId(id);
	}, []);

	return deviceId;
}

