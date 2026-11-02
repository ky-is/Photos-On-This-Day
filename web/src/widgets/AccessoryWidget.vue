<script setup vapor lang="ts">
import { computed } from 'vue'

import { today } from '../days'
import { PHOTOS, photoYear } from '../photos'

// The Lock Screen widgets: how many photos there are from past years today. Circular shows the count under a photo
// icon; rectangular spells it out with the span of years.
const { kind } = defineProps<{ kind: 'circular' | 'rectangular' }>()

const years = computed(() =>
	Object.values(PHOTOS)
		.map(photoYear)
		.filter(year => year < today.value.getFullYear()),
)
const count = computed(() => years.value.length)
const span = computed(() => `${Math.min(...years.value)}–${Math.max(...years.value)}`)
</script>

<template>
	<div class="widget" :class="kind">
		<div class="face tilt-card">
			<template v-if="kind === 'circular'">
				<svg viewBox="0 0 24 24" aria-hidden="true">
					<rect x="6" y="3.5" width="15" height="12" rx="2.5" />
					<path d="M3 8.5v8a3 3 0 0 0 3 3h11" />
				</svg>
				<b>{{ count }}</b>
			</template>
			<template v-else>
				<b>On This Day</b>
				<span>{{ count }} photos</span>
				<small>{{ span }}</small>
			</template>
		</div>
	</div>
</template>

<style scoped>
.widget {
	container-type: inline-size;
	&.circular {
		aspect-ratio: 1;
		--base: 72;
	}
	&.rectangular {
		aspect-ratio: 172 / 76;
		--base: 172;
	}
}

.face {
	--pt: calc(100cqw / var(--base));
	position: relative;
	height: 100%;
	overflow: clip;
	color: white;
	font-family: ui-rounded, 'SF Pro Rounded', system-ui, sans-serif;
	line-height: 1.15;
	text-shadow: 0 1px 6px oklch(0.2 0.05 330 / 0.35);
}

.circular .face {
	display: grid;
	place-content: center;
	justify-items: center;
	border-radius: 50%;
	background: oklch(1 0 0 / 0.18);
	backdrop-filter: blur(12px) saturate(1.4);
	svg {
		width: calc(var(--pt) * 17);
		fill: none;
		stroke: currentColor;
		stroke-width: 2.2;
		stroke-linecap: round;
	}
	b {
		font-size: calc(var(--pt) * 22);
		font-weight: 700;
	}
}

.rectangular .face {
	display: grid;
	align-content: center;
	padding: 0 calc(var(--pt) * 10);
	border-radius: calc(var(--pt) * 16);
	font-size: calc(var(--pt) * 15);
	font-weight: 500;
	b {
		font-size: calc(var(--pt) * 17);
		font-weight: 700;
	}
	small {
		font-size: inherit;
		opacity: 0.6;
	}
	/* Lock Screen text sits straight on the wallpaper, with no surface to catch the light or cast a shadow. */
	box-shadow: none;
	&::before,
	&::after {
		content: none;
	}
}
</style>
