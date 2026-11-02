<script setup vapor lang="ts">
import { GITHUB_URL } from '../pages'
</script>

<template>
	<section class="night" aria-labelledby="privacy-title">
		<div class="moon" aria-hidden="true"></div>
		<div class="wrap reveal">
			<p class="eyebrow">Private by design</p>
			<h2 id="privacy-title">Your memories stay yours.</h2>
			<p class="lede"><strong>No ads, ever.</strong> Photos On This Day reads your library right on your device: nothing is uploaded, nothing is tracked, and there’s no account to sign in to. It’s open source, so you can <a :href="GITHUB_URL">read every line</a> on GitHub.</p>
		</div>
	</section>
</template>

<style scoped>
.night {
	position: relative;
	isolation: isolate;
	overflow: clip;
	padding: clamp(5rem, 10vw, 8rem) 0;
	color: oklch(0.96 0.015 330);
	background: radial-gradient(1px 1px at 10% 20%, white 50%, transparent), radial-gradient(1px 1px at 30% 70%, white 50%, transparent), radial-gradient(1.5px 1.5px at 55% 15%, white 50%, transparent), radial-gradient(1px 1px at 75% 55%, white 50%, transparent), radial-gradient(1px 1px at 90% 25%, white 50%, transparent), radial-gradient(1px 1px at 20% 85%, white 50%, transparent), radial-gradient(1.5px 1.5px at 65% 85%, white 50%, transparent), linear-gradient(to bottom, oklch(0.2 0.04 290), oklch(0.28 0.06 320));
	.eyebrow {
		color: oklch(0.85 0.09 50);
	}
}

.moon {
	position: absolute;
	right: max(var(--gutter), calc((100vw - var(--width)) / 2));
	top: 18%;
	z-index: -1;
	width: clamp(6rem, 16vw, 13rem);
	aspect-ratio: 1;
	border-radius: 50%;
	background: radial-gradient(circle at 35% 35%, oklch(0.97 0.02 85), oklch(0.88 0.03 80));
	box-shadow: 0 0 80px 10px oklch(0.9 0.04 80 / 0.25);
	mask: radial-gradient(circle at 72% 30%, transparent 38%, black 39%);
}

.wrap {
	display: grid;
	gap: 1.25rem;
}

h2 {
	font-size: clamp(2.5rem, 6vw, 4.5rem);
	max-width: 14ch;
}

.lede {
	max-width: 38rem;
	font-size: clamp(1.0625rem, 1.6vw, 1.25rem);
	color: oklch(0.85 0.02 330);
	strong {
		color: white;
		font-weight: 700;
	}
	a {
		color: oklch(0.88 0.09 50);
		text-underline-offset: 0.2em;
	}
}
</style>
