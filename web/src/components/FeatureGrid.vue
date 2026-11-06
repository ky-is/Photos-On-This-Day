<script setup vapor lang="ts">
import { useTemplateRef } from 'vue'

import { PHOTOS as P } from '../photos'
import { useTilt } from '../tilt'
import AccessoryWidget from '../widgets/AccessoryWidget.vue'
import PhotoWidget from '../widgets/PhotoWidget.vue'
import YearsWidget from '../widgets/YearsWidget.vue'
import AppScreen from './AppScreen.vue'

const WIDGET = P.cat
const YEARS_WIDGET = [P.cathedralRock, P.brooklynBridge, P.chickens, P.ringPool]
const mock = useTemplateRef<HTMLElement>('mock')
useTilt(mock)
const VIEWER = [P.beaconHill, P.prospectPark, P.workingLights, P.statenFerry, P.iguana]

const FEATURES = [
	{ title: 'Share the day', text: 'Turn today into a post, a story or a slideshow video, with the best photo from each year picked for you.', shape: 'M12 3v12M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6' },
	{ title: 'Ask Siri', text: 'Show a day’s photos, a chosen year, a random memory, or how many photos today has. All in Shortcuts too.', shape: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z' },
	{ title: 'The whole family', text: 'Includes your Shared Library and iCloud Shared Photos from friends and family. Hide any photo you’d rather not see again.', shape: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 12 0v1M16 3.5a4 4 0 0 1 0 7M22 21v-1a6 6 0 0 0-4-5.6' },
]
</script>

<template>
	<section id="features" class="features" aria-labelledby="features-title">
		<div class="wrap">
			<header class="reveal">
				<h2 id="features-title">Small moments, beautifully resurfaced.</h2>
			</header>
			<div class="grid">
				<article class="tile widgets reveal">
					<div class="copy">
						<h3>A new memory on your Home Screen</h3>
						<p>Widgets in every size, including a Years widget with one photo from each past year, and Lock Screen widgets with today’s count. Choose how often they change, or tap shuffle for another.</p>
					</div>
					<div ref="mock" class="mock">
						<div class="slot at-years" data-tilt="1"><YearsWidget :photos="YEARS_WIDGET" size="large" /></div>
						<div class="slot at-small" data-tilt="1.4"><PhotoWidget :photos="[WIDGET]" size="small" /></div>
						<div class="slot at-circle" data-tilt="1.8"><AccessoryWidget kind="circular" /></div>
					</div>
				</article>
				<article class="tile viewer reveal">
					<div class="copy">
						<h3>A viewer worth lingering in</h3>
						<p>Photos zoom open from the grid. Pinch, scrub the filmstrip, watch Live Photos and videos play, and see where each was taken on a map.</p>
					</div>
					<div class="shot"><AppScreen :photos="VIEWER" /></div>
				</article>
				<article v-for="feature in FEATURES" :key="feature.title" class="tile small reveal">
					<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path :d="feature.shape" /></svg>
					<h3>{{ feature.title }}</h3>
					<p>{{ feature.text }}</p>
				</article>
			</div>
		</div>
	</section>
</template>

<style scoped>
.features {
	padding: clamp(4rem, 8vw, 7rem) 0;
}

header {
	display: grid;
	gap: 1rem;
	max-width: 40rem;
	margin-bottom: clamp(2rem, 4vw, 3.5rem);
}

h2 {
	font-size: clamp(2.25rem, 5vw, 3.75rem);
}

.grid {
	display: grid;
	grid-template-columns: repeat(6, 1fr);
	gap: 1rem;
}

.tile {
	container-type: inline-size;
	position: relative;
	overflow: clip;
	padding: clamp(1.5rem, 3vw, 2.25rem);
	border-radius: var(--radius);
	corner-shape: superellipse(1.3);
	background: var(--paper-raised);
	border: 1px solid var(--line);
	box-shadow: 0 1px 2px oklch(0.2 0.05 330 / 0.04);
	h3 {
		font-size: clamp(1.375rem, 2.2vw, 1.75rem);
		margin-bottom: 0.6rem;
	}
	p {
		color: var(--ink-soft);
	}
}

.widgets {
	grid-column: span 4;
	display: grid;
	grid-template-columns: 1fr 1.1fr;
	gap: 2rem;
	align-items: center;
	background: linear-gradient(150deg, light-dark(oklch(0.96 0.03 30), oklch(0.26 0.04 330)), light-dark(oklch(0.93 0.04 60), oklch(0.22 0.03 300)));
}

.viewer {
	grid-column: span 2;
	display: flex;
	flex-direction: column;
	gap: 1.5rem;
	padding-bottom: 0;
	background: linear-gradient(to bottom, var(--paper-raised), light-dark(oklch(0.93 0.03 120), oklch(0.25 0.03 130)));
	.shot {
		width: min(78%, 16rem);
		/* Runs a little past the tile's clipped bottom edge, so it still bleeds off the edge when hover lifts it. */
		margin: auto auto -0.75rem;
		border-radius: 2rem 2rem 0 0;
		border: 6px solid oklch(0.18 0.01 300);
		border-bottom: 0;
		overflow: clip;
		box-shadow: var(--shadow);
		transition: translate 0.6s var(--ease-spring);
	}
	&:hover .shot {
		translate: 0 -0.5rem;
	}
}

.small {
	grid-column: span 2;
	.icon {
		width: 2.75rem;
		height: 2.75rem;
		padding: 0.6rem;
		margin-bottom: 1.25rem;
		border-radius: 0.85rem;
		background: color-mix(in oklch, var(--accent) 14%, transparent);
		fill: none;
		stroke: var(--accent);
		stroke-width: 1.8;
		stroke-linecap: round;
		stroke-linejoin: round;
	}
}

/* The real widgets, tilting toward the pointer like the ones in the hero. */
.mock {
	position: relative;
	aspect-ratio: 1.25;
	.slot {
		position: absolute;
	}
	.at-years {
		left: 0;
		top: 4%;
		width: 58%;
	}
	.at-small {
		right: 2%;
		top: 0;
		width: 36%;
	}
	.at-circle {
		right: 12%;
		bottom: 8%;
		width: 18%;
		z-index: 1;
	}
}

/* Lock Screen text is white, so its gauge gets a dusk-coloured backdrop on this light tile. */
.at-circle :deep(.face) {
	background: color-mix(in oklch, var(--sky-top) 75%, transparent);
}

@media (max-width: 960px) {
	.grid {
		grid-template-columns: repeat(2, 1fr);
	}
	.widgets {
		grid-column: 1 / -1;
	}
	/* The tall phone tile takes the left column, with the three small tiles stacked beside it. */
	.viewer {
		grid-column: 1;
		grid-row: span 3;
	}
	.small {
		grid-column: 2;
	}
}

@media (max-width: 640px) {
	.grid {
		grid-template-columns: 1fr;
	}
	.widgets {
		grid-template-columns: 1fr;
	}
	.viewer,
	.small {
		grid-column: 1;
		grid-row: auto;
	}
}
</style>
