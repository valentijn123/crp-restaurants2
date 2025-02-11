import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import postcss from './postcss.config.js'
import { resolve } from "path"

// https://vitejs.dev/config/
export default defineConfig({
    css: {
      postcss,
    },
    plugins: [
      svelte({
        hot: {
          // Opt out of preserving state on hot reload
          preserveState: false,
          // Prevent automatic reload of the page
          injectCss: true,
        }
      })
    ],
    base: './', // fivem nui needs to have local dir reference
    resolve: {
      alias: {
        '@components': resolve(__dirname, './src/components'),
        '@stores': resolve(__dirname, './src/stores'),
        '@utils': resolve(__dirname, './src/utils'),
        '@enums': resolve(__dirname, './src/enums'),
        '@providers': resolve(__dirname, './src/providers'),
      },
    },
    server: {
        port: 3000,
      },
    build: {
      emptyOutDir: true,
      outDir: '../build',
      assetsDir: './',
      rollupOptions: {
        output: {
          // By not having hashes in the name, you don't have to update the manifest, yay!
          entryFileNames: `[name].js`,
          chunkFileNames: `[name].js`,
          assetFileNames: `[name].[ext]`
        }
      }
    }
    
  })
  