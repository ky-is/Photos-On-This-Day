import { createVaporApp, createVaporSSRApp } from 'vue'

import '@fontsource-variable/fraunces/full.css'
import './styles.css'

import App from './App.vue'
import { syncToday } from './days'
import { revealOnScroll } from './reveal'
import type { PageName } from './pages'

const container = document.querySelector('#app')!
const page = (document.body.dataset.page ?? 'home') as PageName

// Built pages arrive prerendered (build/prerender.ts) and hydrate; the dev server serves an empty container.
const app = container.firstElementChild ? createVaporSSRApp(App, { page }) : createVaporApp(App, { page })
app.mount(container)
revealOnScroll()

syncToday()
// Keeps the calendar honest for tabs left open past midnight.
document.addEventListener('visibilitychange', () => {
	if (document.visibilityState === 'visible') {
		syncToday()
	}
})
