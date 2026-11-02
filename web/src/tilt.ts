import { onBeforeUnmount, onMounted, type ShallowRef } from 'vue'

interface State {
	rx: number
	ry: number
	gx: number
	gy: number
	px: number
	py: number
}

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value))

// Tilts every [data-tilt] element inside root a little toward the pointer, like a card held up to the light. The tilt
// is linear in the pointer's position across the window, the same for every widget, and at most maxTilt degrees at the
// edges. Each element gets CSS variables: --rx/--ry (rotation), --gx/--gy (where the light hits, in %), --px/--py
// (parallax shift, scaled by the data-tilt depth) and --sx/--sy (its shadow, cast away from the light). With no pointer
// (touch screens, or a resting mouse) a slow drift keeps the light moving.
export function useTilt(root: Readonly<ShallowRef<HTMLElement | null>>, { maxTilt = 11, idleAfter = 3500 } = {}) {
	let frame = 0
	let visible = false
	let pointer: { x: number; y: number } | null = null
	let lastMove = 0
	const startedAt = performance.now()
	const states = new WeakMap<HTMLElement, State>()

	function onPointer(event: PointerEvent) {
		pointer = { x: event.clientX, y: event.clientY }
		lastMove = performance.now()
	}

	function tick(now: number) {
		frame = 0
		const host = root.value
		if (!visible || !host) {
			return
		}
		// Where the pointer is across the window, from -1 (left or top edge) to 1 (right or bottom edge).
		let nx: number
		let ny: number
		if (!pointer || now - lastMove > idleAfter) {
			const t = (now - startedAt) / 1000
			nx = 0.6 * Math.sin(t * 0.4)
			ny = 0.5 * Math.sin(t * 0.55 + 1.2)
		} else {
			nx = clamp((pointer.x / innerWidth) * 2 - 1, -1, 1)
			ny = clamp((pointer.y / innerHeight) * 2 - 1, -1, 1)
		}
		const goal = { rx: -ny * maxTilt, ry: nx * maxTilt, gx: 50 + nx * 45, gy: 50 + ny * 45 }

		for (const element of host.querySelectorAll<HTMLElement>('[data-tilt]')) {
			const depth = Number(element.dataset.tilt) || 1
			const target: State = { ...goal, px: nx * depth * 3, py: ny * depth * 2.5 }
			const state = states.get(element) ?? { ...target }
			// A little smoothing, so the widgets glide rather than jump with every pointer event.
			for (const key of Object.keys(target) as (keyof State)[]) {
				state[key] += (target[key] - state[key]) * 0.12
			}
			states.set(element, state)
			const style = element.style
			style.setProperty('--rx', `${state.rx.toFixed(2)}deg`)
			style.setProperty('--ry', `${state.ry.toFixed(2)}deg`)
			style.setProperty('--gx', `${state.gx.toFixed(1)}%`)
			style.setProperty('--gy', `${state.gy.toFixed(1)}%`)
			style.setProperty('--px', `${state.px.toFixed(1)}px`)
			style.setProperty('--py', `${state.py.toFixed(1)}px`)
			style.setProperty('--sx', `${(-state.ry * 1.5).toFixed(1)}px`)
			style.setProperty('--sy', `${(state.rx * 1.5 + 16).toFixed(1)}px`)
		}
		frame = requestAnimationFrame(tick)
	}

	let observer: IntersectionObserver | undefined
	onMounted(() => {
		if (!root.value || matchMedia('(prefers-reduced-motion: reduce)').matches) {
			return
		}
		window.addEventListener('pointermove', onPointer, { passive: true })
		window.addEventListener('pointerdown', onPointer, { passive: true })
		observer = new IntersectionObserver(([entry]) => {
			visible = entry?.isIntersecting ?? false
			if (visible && !frame) {
				frame = requestAnimationFrame(tick)
			}
		})
		observer.observe(root.value)
	})

	onBeforeUnmount(() => {
		observer?.disconnect()
		cancelAnimationFrame(frame)
		window.removeEventListener('pointermove', onPointer)
		window.removeEventListener('pointerdown', onPointer)
	})
}
