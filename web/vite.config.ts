import { cloudflare } from '@cloudflare/vite-plugin'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite-plus'

import { PAGES, prerender } from './build/prerender.ts'
import { vaporOnly } from './build/vapor-only.ts'

export default defineConfig({
	fmt: {
		arrowParens: 'avoid',
		printWidth: 0,
		semi: false,
		singleQuote: true,
		useTabs: true,
		ignorePatterns: ['dist/**'],
	},

	lint: {
		plugins: ['eslint', 'oxc', 'typescript', 'unicorn', 'vue'],
		ignorePatterns: ['dist/**'],
		overrides: [
			{
				// The browser bundle runs on Vapor alone: any of these would bring back Vue's virtual DOM runtime.
				files: ['src/**'],
				excludeFiles: ['src/render.ts'],
				rules: {
					'no-restricted-imports': ['error', { paths: [{ name: 'vue', importNames: ['createApp', 'createSSRApp', 'h', 'vaporInteropPlugin'], message: 'It brings back the virtual DOM runtime. Use createVaporApp or createVaporSSRApp.' }] }],
				},
			},
		],
	},

	define: {
		// The day the site was built, which the prerendered page shows until the browser swaps in its own today.
		__BUILD_DATE__: JSON.stringify(new Date().toISOString().slice(0, 10)),
	},

	plugins: [vaporOnly(), vue(), prerender(), cloudflare()],

	build: {
		target: ['safari17', 'chrome120', 'firefox121'],
		cssMinify: 'lightningcss',
		rolldownOptions: {
			input: Object.fromEntries(PAGES.map(page => [page.name, page.html])),
		},
	},
})
