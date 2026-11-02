<script setup vapor lang="ts">
import { APP_STORE_URL, type PageName } from '../pages'
import AppIcon from './AppIcon.vue'

const { page } = defineProps<{ page: PageName }>()
</script>

<template>
	<header class="site-header">
		<nav class="wrap" aria-label="Main">
			<a class="brand" href="/" :aria-current="page === 'home' ? 'page' : undefined">
				<AppIcon :size="34" />
				<span>Photos On This Day</span>
			</a>
			<ul>
				<li class="optional"><a href="/#features">Features</a></li>
				<li class="optional"><a href="/privacy/" :aria-current="page === 'privacy' ? 'page' : undefined">Privacy</a></li>
				<li class="optional"><a href="/support/" :aria-current="page === 'support' ? 'page' : undefined">Support</a></li>
				<li><a class="get" :href="APP_STORE_URL">Get the app</a></li>
			</ul>
		</nav>
	</header>
</template>

<style scoped>
.site-header {
	position: fixed;
	inset: 0 0 auto;
	z-index: 50;
	padding-top: env(safe-area-inset-top);
	color: oklch(0.99 0.01 70);
	border-bottom: 1px solid transparent;
}

/* Turns from clear over the sky into frosted paper as the page scrolls. */
@supports (animation-timeline: scroll()) {
	.site-header {
		animation: frost linear both;
		animation-timeline: scroll(root);
		animation-range: 0 14rem;
	}
}

@supports not (animation-timeline: scroll()) {
	.site-header {
		background: color-mix(in oklch, var(--sky-top) 70%, transparent);
		backdrop-filter: blur(20px) saturate(1.6);
	}
}

@keyframes frost {
	to {
		color: var(--ink);
		background: color-mix(in oklch, var(--paper) 72%, transparent);
		backdrop-filter: blur(20px) saturate(1.6);
		border-bottom-color: var(--line);
	}
}

nav {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 1rem;
	height: 4rem;
}

.brand {
	display: flex;
	align-items: center;
	gap: 0.7rem;
	text-decoration: none;
	font: 600 1.0625rem/1 var(--serif);
	letter-spacing: -0.01em;
	white-space: nowrap;
}

ul {
	display: flex;
	align-items: center;
	gap: 0.25rem;
	margin: 0;
	padding: 0;
	list-style: none;
}

ul a {
	display: block;
	padding: 0.5rem 0.85rem;
	border-radius: 99px;
	text-decoration: none;
	font-size: 0.9375rem;
	font-weight: 500;
	transition: background 0.2s;
	&:hover {
		background: color-mix(in oklch, currentColor 12%, transparent);
	}
	&[aria-current='page'] {
		background: color-mix(in oklch, currentColor 14%, transparent);
	}
}

.get {
	margin-left: 0.4rem;
	background: oklch(0.99 0.01 70);
	color: oklch(0.25 0.03 330);
	font-weight: 600;
	box-shadow: 0 2px 10px -2px oklch(0.2 0.05 330 / 0.3);
	transition: scale 0.35s var(--ease-spring);
	&:hover {
		background: oklch(1 0 0);
		scale: 1.05;
	}
}

@media (max-width: 760px) {
	.optional {
		display: none;
	}
}

@media (max-width: 420px) {
	.brand span {
		display: none;
	}
}
</style>
