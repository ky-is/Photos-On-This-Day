<script setup vapor lang="ts">
import { useTemplateRef } from 'vue'

import { PHOTOS as P } from '../photos'
import { useTilt } from '../tilt'
import AccessoryWidget from './AccessoryWidget.vue'
import PhotoWidget from './PhotoWidget.vue'
import YearsWidget from './YearsWidget.vue'

// A Home Screen's worth of widgets floating in the sky, each at its own depth.
// All taken around October 31, like a real day in the app. The large one shuffles.
const LARGE = [P.ferryHome, P.dusk1731, P.doubleRainbow, P.torookiFalls, P.autumnReflection, P.rockyMountain, P.flatirons]
const SMALL = [P.fungus]
const YEARS = [P.window, P.dusk1702, P.saturnJupiter]

const root = useTemplateRef<HTMLElement>('root')
useTilt(root)
</script>

<template>
	<div ref="root" class="hero-widgets" role="group" aria-label="Photos On This Day widgets">
		<div class="slot at-rect" data-tilt="1.6"><AccessoryWidget kind="rectangular" /></div>
		<div class="slot at-circle" data-tilt="1.8"><AccessoryWidget kind="circular" /></div>
		<div class="slot at-small" data-tilt="0.6"><PhotoWidget :photos="SMALL" size="small" /></div>
		<div class="slot at-large" data-tilt="1"><PhotoWidget :photos="LARGE" size="large" /></div>
		<div class="slot at-years" data-tilt="1.4"><YearsWidget :photos="YEARS" size="medium" /></div>
	</div>
</template>

<style scoped>
.hero-widgets {
	position: relative;
	width: min(100%, 36rem);
	aspect-ratio: 1 / 1.08;
	margin-inline: auto;
}

.slot {
	position: absolute;
}

.at-rect {
	left: 3%;
	top: 2%;
	width: 33%;
	z-index: 3;
}

.at-circle {
	left: 39%;
	top: 1%;
	width: 14.5%;
	z-index: 3;
}

.at-small {
	right: 2%;
	top: 0;
	width: 30%;
}

.at-large {
	left: 0;
	top: 16%;
	width: 60%;
	z-index: 1;
}

.at-years {
	right: 0;
	top: 75%;
	width: 64%;
	z-index: 2;
}

/* Widgets pop in one after another, then bob gently at their own pace. */
@media (prefers-reduced-motion: no-preference) {
	.slot {
		animation:
			pop 1.1s var(--ease-spring) both,
			bob 7s ease-in-out 1.2s infinite alternate;
	}
	.at-circle {
		animation-delay: 0.1s, 1.4s;
	}
	.at-small {
		animation-delay: 0.2s, 2s;
	}
	.at-large {
		animation-delay: 0.3s, 1.1s;
	}
	.at-years {
		animation-delay: 0.45s, 2.6s;
	}
}

@keyframes pop {
	from {
		opacity: 0;
		scale: 0.85;
		translate: 0 2rem;
	}
}

@keyframes bob {
	to {
		translate: 0 -0.3rem;
	}
}
</style>
