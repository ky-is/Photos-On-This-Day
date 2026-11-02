<script setup vapor lang="ts">
import { computed } from 'vue'

import { photoYear, type Photo } from '../photos'

// The Years widget: one photo from each past year on this day, labelled with its year. Medium shows three in a row,
// large a 2 × 2 grid, with 2pt between tiles on black.
const { photos, size } = defineProps<{ photos: Photo[]; size: 'medium' | 'large' }>()

const tiles = computed(() => photos.slice(0, size === 'medium' ? 3 : 4).map(photo => ({ photo, year: photoYear(photo) })))
</script>

<template>
	<div class="widget" :class="size">
		<div class="face tilt-card">
			<figure v-for="tile in tiles" :key="tile.photo.src">
				<img :src="tile.photo.src" :alt="tile.photo.alt" decoding="async" />
				<figcaption>{{ tile.year }}</figcaption>
			</figure>
		</div>
	</div>
</template>

<style scoped>
.widget {
	container-type: inline-size;
	--base: 364;
	&.medium {
		aspect-ratio: 364 / 170;
	}
	&.large {
		aspect-ratio: 364 / 382;
	}
}

.face {
	--pt: calc(100cqw / var(--base));
	position: relative;
	display: grid;
	grid-template-columns: repeat(3, 1fr);
	gap: calc(var(--pt) * 2);
	height: 100%;
	border-radius: calc(var(--pt) * 24);
	corner-shape: superellipse(1.6);
	overflow: clip;
	background: black;
	font-family: ui-rounded, 'SF Pro Rounded', system-ui, sans-serif;
	.large & {
		grid-template-columns: repeat(2, 1fr);
	}
}

figure {
	position: relative;
	margin: 0;
	min-height: 0;
	background: oklch(0.08 0 0);
	img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
}

figcaption {
	position: absolute;
	left: calc(var(--pt) * 10);
	bottom: calc(var(--pt) * 8);
	color: white;
	font-size: calc(var(--pt) * 17);
	font-weight: 600;
	text-shadow: 0 calc(var(--pt) * 1) calc(var(--pt) * 1.5) black;
}
</style>
