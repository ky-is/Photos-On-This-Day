<script setup vapor lang="ts">
import { computed } from 'vue'

import { fromISO, longDate } from '../days'
import type { Photo } from '../photos'

// The app's photo viewer on iPhone, drawn in HTML so it can show any photos: the first photo with its place and date,
// and the filmstrip of the day's photos below. Sizes are in container units, so it scales with the frame around it.
const { photos } = defineProps<{ photos: Photo[] }>()

const shown = computed(() => photos[0])
</script>

<template>
	<div class="screen" aria-hidden="true">
		<div class="status">
			<b>9:41</b>
			<span class="glyphs"><i class="signal"></i><i class="wifi"></i><i class="battery"></i></span>
		</div>
		<template v-if="shown">
			<div class="bar">
				<span class="pill round"><i class="chev left"></i></span>
				<span class="caption">
					<b>{{ shown.place }}</b>
					<small>{{ longDate(fromISO(shown.date)) }}</small>
				</span>
				<span class="pill">
					<svg class="ico" viewBox="0 0 24 24"><path d="M12 3v12M8 7l4-4 4 4M5 11v8a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-8" /></svg>
					<svg class="ico heart" viewBox="0 0 24 24"><path d="M12 20.5s-7.5-4.6-9.4-9.2C1.1 7.7 3.4 4 7 4c2.2 0 3.6 1.2 5 3 1.4-1.8 2.8-3 5-3 3.6 0 5.9 3.7 4.4 7.3-1.9 4.6-9.4 9.2-9.4 9.2z" /></svg>
				</span>
			</div>
			<div class="stage">
				<img :src="shown.src" alt="" :width="shown.width" :height="shown.height" loading="lazy" decoding="async" />
			</div>
			<div class="strip">
				<img v-for="(photo, index) in photos" :key="photo.src" :src="photo.src" :class="{ current: index === 0 }" alt="" loading="lazy" decoding="async" />
			</div>
		</template>
	</div>
</template>

<style scoped>
.screen {
	--u: 1cqw;
	container-type: inline-size;
	position: relative;
	display: flex;
	flex-direction: column;
	aspect-ratio: 1206 / 2622;
	overflow: clip;
	background: white;
	color: black;
	font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
}

.status {
	display: flex;
	align-items: center;
	justify-content: space-between;
	padding: calc(var(--u) * 5) calc(var(--u) * 9) calc(var(--u) * 2.5);
	font-size: calc(var(--u) * 4.2);
}

.glyphs {
	display: flex;
	align-items: center;
	gap: 0.35em;
	i {
		display: block;
		height: 0.75em;
		background: currentColor;
		border-radius: 0.15em;
	}
	.signal {
		width: 1.1em;
		clip-path: polygon(0 100%, 100% 0, 100% 100%);
	}
	.wifi {
		width: 1.05em;
		border-radius: 50% 50% 0 0;
		clip-path: polygon(50% 100%, 0 25%, 100% 25%);
	}
	.battery {
		width: 1.6em;
		background: oklch(0.72 0.19 145);
		border-radius: 0.25em;
	}
}

.bar {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: calc(var(--u) * 2);
	padding: calc(var(--u) * 1.5) calc(var(--u) * 4);
}

.pill {
	display: flex;
	align-items: center;
	gap: calc(var(--u) * 5);
	height: calc(var(--u) * 11.5);
	padding: 0 calc(var(--u) * 4.5);
	border-radius: 99px;
	background: oklch(0.98 0 0 / 0.9);
	box-shadow:
		0 0 0 1px oklch(0 0 0 / 0.06),
		0 calc(var(--u) * 1) calc(var(--u) * 4) oklch(0 0 0 / 0.1);
	&.round {
		width: calc(var(--u) * 11.5);
		padding: 0;
		justify-content: center;
	}
	i {
		display: grid;
		place-items: center;
		font-style: normal;
	}
}

.chev {
	width: calc(var(--u) * 2.6);
	aspect-ratio: 1;
	border: solid currentColor;
	border-width: calc(var(--u) * 0.7) calc(var(--u) * 0.7) 0 0;
	rotate: 45deg;
	&.left {
		rotate: -135deg;
	}
}

.ico {
	width: calc(var(--u) * 5.2);
	fill: none;
	stroke: currentColor;
	stroke-width: 2;
	stroke-linecap: round;
	stroke-linejoin: round;
	&.heart {
		fill: oklch(0.63 0.22 25);
		stroke: none;
	}
}

.caption {
	display: grid;
	justify-items: center;
	text-align: center;
	line-height: 1.2;
	b {
		font-size: calc(var(--u) * 3.6);
	}
	small {
		font-size: calc(var(--u) * 3);
		color: oklch(0.4 0 0);
	}
}

.stage {
	flex: 1;
	display: grid;
	place-items: center;
	min-height: 0;
	img {
		width: 100%;
		height: 100%;
		object-fit: contain;
	}
}

.strip {
	display: flex;
	justify-content: center;
	gap: 1px;
	padding: calc(var(--u) * 3) 0 calc(var(--u) * 7);
	img {
		width: calc(var(--u) * 7);
		aspect-ratio: 0.7;
		object-fit: cover;
		&.current {
			width: calc(var(--u) * 11);
			margin-inline: calc(var(--u) * 1);
			border-radius: calc(var(--u) * 0.6);
		}
	}
}
</style>
