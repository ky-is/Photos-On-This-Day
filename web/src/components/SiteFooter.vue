<script setup vapor lang="ts">
import { APP_STORE_URL, GITHUB_URL } from '../pages'
import AppIcon from './AppIcon.vue'

const year = new Date(__BUILD_DATE__).getUTCFullYear()
</script>

<template>
	<footer class="site-footer">
		<div class="wrap">
			<a class="brand" href="/">
				<AppIcon :size="40" />
				<span>
					<strong>Photos On This Day</strong>
					<small>Relive today from years past</small>
				</span>
			</a>
			<nav aria-label="Footer">
				<a :href="APP_STORE_URL">App Store</a>
				<a href="/privacy/">Privacy</a>
				<a href="/support/">Support</a>
				<a :href="GITHUB_URL">Source code</a>
			</nav>
			<p class="fine">© 2022–{{ year }} Kyle Coburn. iPhone, iPad, Mac and App Store are trademarks of Apple Inc.</p>
		</div>
	</footer>
</template>

<style scoped>
.site-footer {
	padding: 3.5rem 0 calc(3rem + env(safe-area-inset-bottom));
	border-top: 1px solid var(--line);
	background: var(--paper-sunk);
	font-size: 0.9375rem;
}

.wrap {
	display: grid;
	grid-template-columns: 1fr auto;
	align-items: center;
	gap: 2rem;
}

.brand {
	display: flex;
	align-items: center;
	gap: 0.85rem;
	text-decoration: none;
	span {
		display: grid;
	}
	strong {
		font: 600 1.125rem/1.2 var(--serif);
	}
	small {
		color: var(--ink-soft);
	}
}

nav {
	display: flex;
	flex-wrap: wrap;
	gap: 0.5rem 1.5rem;
	a {
		color: var(--ink-soft);
		text-decoration: none;
		&:hover {
			color: var(--ink);
			text-decoration: underline;
			text-underline-offset: 0.2em;
		}
	}
}

.fine {
	grid-column: 1 / -1;
	color: var(--ink-soft);
	font-size: 0.8125rem;
}

@media (max-width: 640px) {
	.wrap {
		grid-template-columns: 1fr;
	}
}
</style>
