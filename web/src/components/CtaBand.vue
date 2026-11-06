<script setup vapor lang="ts">
import AppIcon from './AppIcon.vue'
import AppStoreBadge from './AppStoreBadge.vue'
</script>

<template>
	<section class="cta" aria-labelledby="cta-title">
		<div class="wrap reveal">
			<AppIcon :size="112" />
			<h2 id="cta-title">See what today remembers.</h2>
			<AppStoreBadge :height="58" />
			<p class="promise">No ads. No tracking. Your photos stay private.</p>
		</div>
	</section>
</template>

<style scoped>
.cta {
	padding: clamp(5rem, 10vw, 8rem) 0;
	text-align: center;
	background: radial-gradient(50rem 24rem at 50% 100%, color-mix(in oklch, var(--sky-low) 30%, transparent), transparent);
}

.wrap {
	display: grid;
	justify-items: center;
	gap: 1.25rem;
}

h2 {
	margin-top: 0.75rem;
	font-size: clamp(2.5rem, 6vw, 4.5rem);
}

.promise {
	font-size: 1.0625rem;
	font-weight: 600;
	opacity: 0.8;
}
</style>
