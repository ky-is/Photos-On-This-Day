import fs from 'node:fs/promises'
import path from 'node:path'

import vue from '@vitejs/plugin-vue'
import type { Plugin, ResolvedConfig } from 'vite-plus'

import type { PageName } from '../src/pages.ts'

export const PAGES: { name: PageName, html: string }[] = [
	{ name: 'home', html: 'index.html' },
	{ name: 'privacy', html: 'privacy/index.html' },
	{ name: 'support', html: 'support/index.html' },
]

const OUTLET = '<!--app-->'

// Renders each page to static HTML after the build, so the site reads without JavaScript and search engines see it all.
// The browser then hydrates it with createVaporSSRApp (src/main.ts).
export function prerender(): Plugin {
	let config: ResolvedConfig
	return {
		name: 'onthisday:prerender',
		apply: 'build',
		configResolved(resolved) {
			config = resolved
		},
		async closeBundle() {
			if (this.environment.name !== 'client') {
				return
			}
			// The Cloudflare plugin moves the client build into its Build Output, so read the folder from the environment.
			const outDir = path.resolve(config.root, this.environment.config.build.outDir)
			const { createServer } = await import('vite-plus')
			// Only the Vue plugin, with the build's mode so scoped style ids match the bundle's; the Cloudflare plugin
			// would start a local Workers runtime here for nothing.
			const server = await createServer({
				configFile: false,
				root: config.root,
				mode: config.mode,
				define: config.define,
				plugins: [vue()],
				logLevel: 'error',
				appType: 'custom',
				server: { middlewareMode: true, hmr: false, ws: false },
				optimizeDeps: { noDiscovery: true, include: [] },
			})
			try {
				const { render } = (await server.ssrLoadModule('/src/render.ts')) as typeof import('../src/render.ts')
				for (const page of PAGES) {
					const file = path.join(outDir, page.html)
					const html = await fs.readFile(file, 'utf8')
					if (!html.includes(OUTLET)) {
						throw new Error(`${page.html} has no ${OUTLET}`)
					}
					await fs.writeFile(file, html.replace(OUTLET, await render(page.name)))
				}
				config.logger.info(`Prerendered ${PAGES.length} pages`)
			} finally {
				await server.close()
			}
		},
	}
}
