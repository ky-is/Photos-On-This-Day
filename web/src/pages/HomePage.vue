<script setup vapor lang="ts">
import { computed } from 'vue'

import AppStoreBadge from '../components/AppStoreBadge.vue'
import CtaBand from '../components/CtaBand.vue'
import DuskScene from '../components/DuskScene.vue'
import FeatureGrid from '../components/FeatureGrid.vue'
import PrivacyBand from '../components/PrivacyBand.vue'
import { monthName, selected } from '../days'
import HeroWidgets from '../widgets/HeroWidgets.vue'

const day = computed(() => `${monthName(selected.value)} ${selected.value.getDate()}`)
</script>

<template>
	<DuskScene>
		<div class="hero wrap">
			<div class="copy">
				<h1>Where were you a year ago today?</h1>
				<p class="lede">Rediscover the photos you took on {{ day }} in every year past, from last year all the way back. Right on your Home Screen. <strong>No ads, ever.</strong></p>
				<div class="actions">
					<AppStoreBadge />
				</div>
			</div>
			<HeroWidgets />
		</div>
	</DuskScene>
	<FeatureGrid />
	<PrivacyBand />
	<CtaBand />
</template>

<style scoped>
.hero {
	display: grid;
	grid-template-columns: 1.15fr 1fr;
	align-items: center;
	gap: clamp(2rem, 5vw, 5rem);
}

.copy {
	display: grid;
	gap: 1.4rem;
	justify-items: start;
}

h1 {
	font-size: clamp(3rem, 7.5vw, 6.25rem);
	font-weight: 520;
	line-height: 0.95;
	letter-spacing: -0.035em;
	text-shadow: 0 2px 40px oklch(0.4 0.08 340 / 0.35);
}

.lede {
	max-width: 32rem;
	font-size: clamp(1.125rem, 1.8vw, 1.375rem);
	line-height: 1.5;
	opacity: 0.95;
	strong {
		font-weight: 700;
	}
}

.actions {
	display: flex;
	flex-wrap: wrap;
	align-items: center;
	gap: 1rem 1.25rem;
	margin-top: 0.5rem;
}

@media (prefers-reduced-motion: no-preference) {
	.copy > * {
		animation: rise 1s var(--ease-out) both;
	}
	.copy > :nth-child(2) {
		animation-delay: 0.08s;
	}
	.copy > :nth-child(3) {
		animation-delay: 0.16s;
	}
	.copy > :nth-child(4) {
		animation-delay: 0.24s;
	}
}

@keyframes rise {
	from {
		opacity: 0;
		translate: 0 1.5rem;
	}
}

@media (max-width: 860px) {
	.hero {
		grid-template-columns: 1fr;
		text-align: center;
	}
	.copy {
		justify-items: center;
	}
	.actions {
		justify-content: center;
	}
}
</style>
