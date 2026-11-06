// Sections (.reveal) stay hidden until they first scroll into view, then rise in once and stay. Elements that come
// into view together, like a row of tiles, follow one another by a beat.
export function revealOnScroll() {
	if (matchMedia('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) {
		return
	}
	const observer = new IntersectionObserver(
		entries => {
			entries
				.filter(entry => entry.isIntersecting)
				.forEach((entry, index) => {
					const element = entry.target as HTMLElement
					element.style.setProperty('--reveal-delay', `${index * 0.08}s`)
					element.classList.add('revealed')
					observer.unobserve(element)
				})
		},
		{ rootMargin: '0px 0px -10% 0px' },
	)
	document.querySelectorAll('.reveal').forEach(element => observer.observe(element))
	// Only hide sections once something is watching for them, so they never stay hidden.
	document.documentElement.classList.add('reveals')
}
