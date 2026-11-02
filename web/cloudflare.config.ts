import { defineConfig } from 'cf/config'

// An assets-only Worker: the prerendered pages and files from Vite's build, served at onthisday.ky.is.
export default defineConfig({
	worker: {
		name: 'onthisday',
		compatibilityDate: '2026-10-30',
		domains: ['onthisday.ky.is'],
		assets: {
			htmlHandling: 'auto-trailing-slash',
			notFoundHandling: 'none',
		},
		workersDev: false,
		previewUrls: false,
	},
})
