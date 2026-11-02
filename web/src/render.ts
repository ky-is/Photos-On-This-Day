import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

import App from './App.vue'
import type { PageName } from './pages'

// Runs in Node at build time (build/prerender.ts). Node's Vue has no Vapor runtime, so the Vapor components render
// through the regular SSR renderer here and hydrate with createVaporSSRApp in the browser.
export function render(page: PageName) {
	return renderToString(createSSRApp(App, { page }))
}
