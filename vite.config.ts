import { defineConfig } from 'vite'
import { devtools } from '@tanstack/devtools-vite'
import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

import { tanstackRouter } from '@tanstack/router-plugin/vite'
import { fileURLToPath, URL } from 'node:url'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    devtools(),
    tanstackRouter({
      target: 'react',
      autoCodeSplitting: true,
    }),
    viteReact({
      babel: {
        plugins: ['babel-plugin-react-compiler'],
      },
    }),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      "@initia/initia.js": fileURLToPath(new URL('./src/lib/initia-stub.ts', import.meta.url)),
    },
  },

  build: {
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        manualChunks: {
          // Split vendor dependencies into separate chunks
          "vendor-react": ["react", "react-dom"],
          "vendor-tanstack": ["@tanstack/react-query", "@tanstack/react-router"],
          "vendor-utils": ["class-variance-authority", "clsx", "tailwind-merge"],
          "vendor-aptos": ["@aptos-labs/ts-sdk", "@aptos-labs/wallet-adapter-react"],
        },
      },
    },
  },
})
