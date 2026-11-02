<script setup vapor lang="ts">
const { compact = false } = defineProps<{ compact?: boolean }>()
</script>

<template>
	<section class="dusk" :class="{ compact }">
		<div class="sky" aria-hidden="true">
			<div class="stars"></div>
			<div class="glow"></div>
			<svg class="hill far" viewBox="0 0 1440 400" preserveAspectRatio="none"><path d="M0 230C220 150 470 140 720 200S1180 270 1440 170V400H0Z" /></svg>
			<svg class="hill mid" viewBox="0 0 1440 400" preserveAspectRatio="none"><path d="M0 290C300 210 590 230 860 285S1260 330 1440 260V400H0Z" /></svg>
			<svg class="hill near" viewBox="0 0 1440 400" preserveAspectRatio="none"><path d="M0 330C250 290 520 320 780 360S1200 340 1440 345V400H0Z" /></svg>
		</div>
		<div class="content">
			<slot />
		</div>
	</section>
</template>

<style scoped>
.dusk {
	position: relative;
	isolation: isolate;
	min-height: max(100svh, 44rem);
	display: grid;
	align-items: center;
	padding: calc(5rem + env(safe-area-inset-top)) 0 clamp(6rem, 14vw, 12rem);
	color: oklch(0.99 0.01 70);
	&.compact {
		min-height: 0;
		padding-bottom: clamp(5rem, 10vw, 8rem);
	}
}

.sky {
	position: absolute;
	inset: 0;
	z-index: -1;
	overflow: clip;
	background: linear-gradient(to bottom, var(--sky-top) 0%, var(--sky-mid) 45%, var(--sky-low) 85%);
}

.stars {
	position: absolute;
	inset: 0 0 40%;
	opacity: light-dark(0, 1);
	background-image: radial-gradient(1px 1px at 12% 18%, white 50%, transparent), radial-gradient(1px 1px at 28% 8%, white 50%, transparent), radial-gradient(1.5px 1.5px at 41% 26%, white 50%, transparent), radial-gradient(1px 1px at 57% 12%, white 50%, transparent), radial-gradient(1px 1px at 69% 30%, white 50%, transparent), radial-gradient(1.5px 1.5px at 83% 16%, white 50%, transparent), radial-gradient(1px 1px at 92% 40%, white 50%, transparent), radial-gradient(1px 1px at 6% 44%, white 50%, transparent), radial-gradient(1px 1px at 35% 48%, white 50%, transparent), radial-gradient(1.5px 1.5px at 76% 6%, white 50%, transparent), radial-gradient(1px 1px at 50% 38%, white 50%, transparent), radial-gradient(1px 1px at 20% 33%, white 50%, transparent);
	mask-image: linear-gradient(to bottom, black, transparent);
}

@media (prefers-reduced-motion: no-preference) {
	.stars {
		animation: twinkle 6s ease-in-out infinite alternate;
	}
}

@keyframes twinkle {
	to {
		opacity: light-dark(0, 0.55);
	}
}

.glow {
	position: absolute;
	left: 50%;
	bottom: 8%;
	width: min(130vw, 90rem);
	aspect-ratio: 2;
	translate: -50% 0;
	background: radial-gradient(closest-side, var(--sun-glow), transparent);
}

.hill {
	position: absolute;
	left: -2%;
	width: 104%;
	bottom: 0;
	height: clamp(9rem, 26vw, 22rem);
	path {
		transition: fill 0.6s;
	}
	&.far path {
		fill: var(--hill-far);
	}
	&.mid path {
		fill: var(--hill-mid);
	}
	&.near {
		bottom: -1px;
		path {
			fill: var(--hill-near);
		}
	}
}

/* Parallax: nearer hills move faster as the hero scrolls away. */
@supports (animation-timeline: scroll()) {
	@media (prefers-reduced-motion: no-preference) {
		.hill,
		.glow {
			animation: drift linear both;
			animation-timeline: scroll(root);
			animation-range: 0 100svh;
		}
		.far {
			--drift: 9rem;
		}
		.mid {
			--drift: 5rem;
		}
		.near {
			--drift: 1.5rem;
		}
		.glow {
			--drift: 14rem;
		}
	}
}

@keyframes drift {
	to {
		translate: var(--tx, 0) var(--drift);
	}
}

.glow {
	--tx: -50%;
}

.content {
	position: relative;
}
</style>
