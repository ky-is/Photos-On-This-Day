<script setup vapor lang="ts">
import { computed, nextTick, ref } from 'vue'

import { longDate, monthDay, relativeAgo, today, yearsAgo } from '../days'
import { photoYear, type Photo } from '../photos'

// The app's photo widget: one photo filling the widget, with its date and how long ago in the corner. Given more than
// one photo, it shows the shuffle button, which works here just like on the Home Screen.
const { photos, size } = defineProps<{ photos: Photo[]; size: 'small' | 'medium' | 'large' }>()

const index = ref(0)
const photo = computed(() => photos[index.value % photos.length]!)
// Always today's date in the photo's year, as if it were taken on this day.
const date = computed(() => yearsAgo(today.value, today.value.getFullYear() - photoYear(photo.value)))
const heading = computed(() => (size === 'large' ? longDate(date.value) : monthDay(date.value)))
const ago = computed(() => relativeAgo(date.value, today.value))

function shuffle() {
	const next = async () => {
		index.value += 1
		await nextTick()
	}
	if (!document.startViewTransition || matchMedia('(prefers-reduced-motion: reduce)').matches) {
		void next()
	} else {
		// A transition is skipped (and rejects) when another starts or the tab is hidden; the photo still changes.
		document.startViewTransition(next).ready.catch(() => {})
	}
}
</script>

<template>
	<div class="widget" :class="size">
		<div class="face tilt-card" :style="photos.length > 1 ? { viewTransitionName: `widget-${size}` } : undefined">
			<img :src="photo.src" :alt="photo.alt" :width="photo.width" :height="photo.height" decoding="async" />
			<p class="label">
				<b v-if="size !== 'small'">{{ heading }}</b>
				<span>{{ ago }}</span>
			</p>
			<button v-if="photos.length > 1" type="button" class="shuffle" aria-label="Shuffle photo" @click="shuffle">
				<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 7h3.5c2 0 3.3 1 4.4 2.6l2.2 4.8c1.1 1.6 2.4 2.6 4.4 2.6H21M3 17h3.5c2 0 3.3-1 4.4-2.6M13.1 9.6c1.1-1.6 2.4-2.6 4.4-2.6H21M18 4l3 3-3 3M18 14l3 3-3 3" /></svg>
			</button>
		</div>
	</div>
</template>

<style scoped>
.widget {
	container-type: inline-size;
	&.small {
		aspect-ratio: 1;
		--base: 170;
	}
	&.medium {
		aspect-ratio: 364 / 170;
		--base: 364;
	}
	&.large {
		aspect-ratio: 364 / 382;
		--base: 364;
	}
}

.face {
	/* One widget point, so sizes read like the SwiftUI code: .padding() is 16pt, .title2 is 22pt. */
	--pt: calc(100cqw / var(--base));
	position: relative;
	height: 100%;
	border-radius: calc(var(--pt) * 24);
	corner-shape: superellipse(1.6);
	overflow: clip;
	background: oklch(0.12 0 0);
	font-family: ui-rounded, 'SF Pro Rounded', system-ui, sans-serif;
	img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
}

.label {
	position: absolute;
	right: calc(var(--pt) * 16);
	bottom: calc(var(--pt) * 14);
	display: grid;
	justify-items: end;
	color: white;
	font-weight: 600;
	line-height: 1.2;
	text-shadow: 0 calc(var(--pt) * 1) calc(var(--pt) * 1.5) black;
	b {
		font-size: calc(var(--pt) * 22);
		font-weight: 600;
	}
	span {
		font-size: calc(var(--pt) * 16);
	}
	.large & b {
		font-size: calc(var(--pt) * 28);
	}
}

.shuffle {
	position: absolute;
	top: calc(var(--pt) * 10);
	right: calc(var(--pt) * 10);
	z-index: 3;
	display: grid;
	place-items: center;
	width: max(calc(var(--pt) * 30), 28px);
	aspect-ratio: 1;
	padding: 0;
	border: 0;
	border-radius: 50%;
	background: oklch(0 0 0 / 0.35);
	backdrop-filter: blur(6px);
	color: white;
	cursor: pointer;
	transition:
		scale 0.3s var(--ease-spring),
		background 0.2s;
	&:hover {
		background: oklch(0 0 0 / 0.5);
		scale: 1.1;
	}
	&:active {
		scale: 0.9;
	}
	svg {
		width: 52%;
		fill: none;
		stroke: currentColor;
		stroke-width: 2.6;
		stroke-linecap: round;
		stroke-linejoin: round;
	}
}
</style>
