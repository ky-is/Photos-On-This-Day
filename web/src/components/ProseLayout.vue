<script setup vapor lang="ts">
import DuskScene from './DuskScene.vue'

const { eyebrow, title, lede } = defineProps<{ eyebrow: string; title: string; lede: string }>()
</script>

<template>
	<DuskScene compact>
		<div class="wrap banner">
			<p class="kicker">{{ eyebrow }}</p>
			<h1>{{ title }}</h1>
			<p class="lede">{{ lede }}</p>
		</div>
	</DuskScene>
	<article class="prose wrap">
		<slot />
	</article>
</template>

<style scoped>
.banner {
	display: grid;
	gap: 1rem;
	max-width: 46rem;
	padding-top: clamp(2rem, 6vw, 5rem);
}

.kicker {
	font: 600 0.875rem/1 var(--sans);
	letter-spacing: 0.16em;
	text-transform: uppercase;
	opacity: 0.85;
}

h1 {
	font-size: clamp(2.75rem, 7vw, 5rem);
	letter-spacing: -0.03em;
}

.lede {
	font-size: clamp(1.125rem, 1.8vw, 1.3rem);
	opacity: 0.95;
}

.prose {
	max-width: 46rem;
	padding: clamp(3rem, 6vw, 5rem) 0 clamp(4rem, 8vw, 6rem);
	:slotted(h2) {
		margin: 2.75rem 0 0.85rem;
		font-size: clamp(1.625rem, 3vw, 2.125rem);
	}
	:slotted(h2:first-child) {
		margin-top: 0;
	}
	:slotted(h3) {
		margin: 1.75rem 0 0.5rem;
		font-size: 1.3rem;
	}
	:slotted(p),
	:slotted(ol),
	:slotted(ul) {
		margin: 0 0 1rem;
		color: var(--ink-soft);
	}
	:slotted(ol),
	:slotted(ul) {
		padding-left: 1.4rem;
	}
	:slotted(li) {
		margin-bottom: 0.4rem;
	}
	:slotted(strong) {
		color: var(--ink);
	}
	:slotted(a) {
		color: var(--accent);
		text-underline-offset: 0.2em;
	}
	:slotted(.note) {
		padding: 1.25rem 1.4rem;
		border-radius: 1.25rem;
		background: var(--paper-sunk);
		border: 1px solid var(--line);
	}
}
</style>
