import { useEffect, useRef } from "react";

interface Particle {
	x: number;
	y: number;
	size: number;
	speedX: number;
	speedY: number;
	opacity: number;
	baseOpacity: number;
	depth: number;
	wobbleOffset: number;
	wobbleSpeed: number;
	flickerOffset: number;
	// Pre-calculated colors for performance
	r: number;
	g: number;
	b: number;
}

// Pre-calculated sin table for performance
const SIN_TABLE_SIZE = 256;
const SIN_TABLE: number[] = [];
for (let i = 0; i < SIN_TABLE_SIZE; i++) {
	SIN_TABLE[i] = Math.sin((i / SIN_TABLE_SIZE) * Math.PI * 2);
}
function fastSin(x: number): number {
	const index = ((x % (Math.PI * 2)) / (Math.PI * 2)) * SIN_TABLE_SIZE;
	return SIN_TABLE[Math.floor(index) & (SIN_TABLE_SIZE - 1)];
}

export function DustParticles() {
	const canvasRef = useRef<HTMLCanvasElement>(null);
	const particlesRef = useRef<Particle[]>([]);
	const animationRef = useRef<number>(0);
	const timeRef = useRef(0);
	const lastFrameRef = useRef(0);

	useEffect(() => {
		const canvas = canvasRef.current;
		if (!canvas) return;

		const ctx = canvas.getContext("2d", { alpha: true });
		if (!ctx) return;

		let width = window.innerWidth;
		let height = window.innerHeight;
		let dpr = window.devicePixelRatio || 1;

		// Set canvas to full screen
		const resize = () => {
			dpr = window.devicePixelRatio || 1;
			width = window.innerWidth;
			height = window.innerHeight;
			canvas.width = width * dpr;
			canvas.height = height * dpr;
			canvas.style.width = `${width}px`;
			canvas.style.height = `${height}px`;
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		};
		resize();
		window.addEventListener("resize", resize);

		// Initialize particles
		const PARTICLE_COUNT = 500;
		const particles: Particle[] = [];

		for (let i = 0; i < PARTICLE_COUNT; i++) {
			particles.push(createParticle(width, height));
		}
		// Sort once at initialization (depth doesn't change)
		particles.sort((a, b) => a.depth - b.depth);
		particlesRef.current = particles;

		// Pre-calculate light source values
		const lightRelX = 0.5;
		const lightRelY = 0.1;
		const lightRadiusFactor = 0.5;

		// Target ~30fps for dust (doesn't need 60fps)
		const TARGET_FRAME_TIME = 1000 / 30;

		// Animation loop
		const animate = (timestamp: number) => {
			// Throttle to target frame rate
			const elapsed = timestamp - lastFrameRef.current;
			if (elapsed < TARGET_FRAME_TIME) {
				animationRef.current = requestAnimationFrame(animate);
				return;
			}
			lastFrameRef.current = timestamp;

			timeRef.current += 0.033; // ~30fps time step
			const time = timeRef.current;

			ctx.clearRect(0, 0, width, height);

			// Pre-calculate light position
			const lightX = lightRelX * width;
			const lightY = lightRelY * height;
			const maxDistSq = Math.pow(lightRadiusFactor * Math.max(width, height), 2);
			const invMaxDistSq = 1 / maxDistSq;

			// Pre-calculate edge fade factors
			const edgeFadeFactorX = 1 / (width * 0.15);
			const edgeFadeFactorY = 1 / (height * 0.1);
			const bottomStart = height * 0.6;
			const bottomRange = height * 0.4;

			for (let i = 0; i < particles.length; i++) {
				const particle = particles[i];

				// Update position with gentle floating motion
				const wobble = fastSin(time * particle.wobbleSpeed + particle.wobbleOffset);
				particle.x += particle.speedX + wobble * 0.1 * particle.depth;
				particle.y += particle.speedY;

				// Respawn at center when leaving screen
				if (particle.x < -20 || particle.x > width + 20 || particle.y < -20 || particle.y > height + 20) {
					const newParticle = createParticle(width, height);
					particle.x = newParticle.x;
					particle.y = newParticle.y;
					particle.speedX = newParticle.speedX;
					particle.speedY = newParticle.speedY;
				}

				// Calculate squared distance from light source (avoid sqrt)
				const dx = particle.x - lightX;
				const dy = particle.y - lightY;
				const distSq = dx * dx + dy * dy;

				// Light intensity falloff using squared distance
				const normalizedDist = distSq * invMaxDistSq;
				let lightIntensity = 1 - normalizedDist * Math.sqrt(normalizedDist); // Approximates pow(dist, 1.5)
				if (lightIntensity < 0) lightIntensity = 0;
				if (lightIntensity > 1) lightIntensity = 1;

				// Shadow zones (simplified calculations)
				const edgeFadeX = Math.min(particle.x * edgeFadeFactorX, (width - particle.x) * edgeFadeFactorX, 1);
				const edgeFadeY = Math.min(particle.y * edgeFadeFactorY, 1);
				const bottomDist = particle.y - bottomStart;
				const bottomFade = bottomDist > 0 ? 1 - (bottomDist / bottomRange) * (bottomDist / bottomRange) : 1;
				const shadowMultiplier = Math.min(edgeFadeX, edgeFadeY) * Math.max(0, bottomFade);

				// Flicker effect (using fast sin)
				const flicker = 0.85 + 0.15 * fastSin(time * 3 + particle.flickerOffset);

				// Calculate final opacity (boosted for better visibility)
				const glowBoost = lightIntensity * 3;
				const opacity = particle.baseOpacity * (0.25 + glowBoost * 0.75) * shadowMultiplier * flicker * particle.depth;

				// Skip nearly invisible particles early
				if (opacity < 0.008) continue;

				particle.opacity = opacity;

				// Update particle color based on light (warm in light, cool in shadow)
				particle.r = 200 + lightIntensity * 55;
				particle.g = 180 + lightIntensity * 50;
				particle.b = 150 - lightIntensity * 50;

				// Draw particle (simplified - single gradient instead of two)
				drawParticleOptimized(ctx, particle);
			}

			animationRef.current = requestAnimationFrame(animate);
		};

		animationRef.current = requestAnimationFrame(animate);

		return () => {
			window.removeEventListener("resize", resize);
			cancelAnimationFrame(animationRef.current);
		};
	}, []);

	return (
		<canvas
			ref={canvasRef}
			className="fixed top-0 left-0 w-screen h-screen pointer-events-none"
			style={{ zIndex: -5 }}
		/>
	);
}

function createParticle(width: number, height: number): Particle {
	const depth = 0.3 + Math.random() * 0.7;

	// Gaussian-like distribution using Box-Muller
	const u1 = Math.random();
	const u2 = Math.random();
	const gaussian = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);

	const centerX = 0.5;
	const centerY = 0.3;
	const spreadX = 0.2;
	const spreadY = 0.22;

	let x = (centerX + gaussian * spreadX) * width;
	// Generate second gaussian for y
	const u3 = Math.random();
	const u4 = Math.random();
	const gaussian2 = Math.sqrt(-2 * Math.log(u3)) * Math.cos(2 * Math.PI * u4);
	let y = (centerY + gaussian2 * spreadY) * height;

	x = Math.max(-20, Math.min(width + 20, x));
	y = Math.max(-20, Math.min(height + 20, y));

	return {
		x,
		y,
		size: (0.3 + Math.random() * 1.2) * depth,
		speedX: (Math.random() - 0.5) * 0.08 * depth,
		speedY: (Math.random() * 0.15 - 0.03) * depth,
		opacity: 0,
		baseOpacity: 0.4 + Math.random() * 0.6,
		depth,
		wobbleOffset: Math.random() * Math.PI * 2,
		wobbleSpeed: 0.5 + Math.random() * 1.5,
		flickerOffset: Math.random() * Math.PI * 2,
		r: 200,
		g: 180,
		b: 150,
	};
}

function drawParticleOptimized(ctx: CanvasRenderingContext2D, particle: Particle) {
	const { x, y, size, opacity, depth, r, g, b } = particle;

	// Glow radius
	const glowSize = size * (1.5 + opacity * 2) * depth;

	// Single gradient for both glow and core (reduces gradient creation by half)
	const gradient = ctx.createRadialGradient(x, y, 0, x, y, glowSize);
	gradient.addColorStop(0, `rgba(255,255,250,${opacity})`);
	gradient.addColorStop(0.15, `rgba(${r | 0},${g | 0},${b | 0},${opacity * 0.8})`);
	gradient.addColorStop(0.4, `rgba(${r | 0},${g | 0},${b | 0},${opacity * 0.35})`);
	gradient.addColorStop(0.7, `rgba(${r | 0},${g | 0},${b | 0},${opacity * 0.1})`);
	gradient.addColorStop(1, `rgba(${r | 0},${g | 0},${b | 0},0)`);

	ctx.beginPath();
	ctx.arc(x, y, glowSize, 0, Math.PI * 2);
	ctx.fillStyle = gradient;
	ctx.fill();
}
