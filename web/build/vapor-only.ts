import type { Plugin } from 'vite-plus'

// Fails the build when a component isn't a Vapor component. One without <script setup vapor> compiles to the virtual
// DOM, which pulls Vue's VDOM runtime back into the bundle and breaks hydration of the prerendered pages.
export function vaporOnly(): Plugin {
	return {
		name: 'onthisday:vapor-only',
		enforce: 'pre',
		transform(code, id) {
			if (id.endsWith('.vue') && !/<script\s+setup\s+vapor\b/.test(code)) {
				this.error(`${id} needs <script setup vapor lang="ts">`)
			}
		},
	}
}
