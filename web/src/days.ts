import { computed, ref } from 'vue'

// Today, as a local calendar day. It starts as the build day so the prerendered HTML and the first client render
// agree, and main.ts moves it to the visitor's own today once the page has hydrated.
export const today = ref(fromISO(__BUILD_DATE__))

// The day the page talks about: today, for now.
export const selected = computed(() => today.value)

export function fromISO(iso: string) {
	const [year, month, day] = iso.split('-').map(Number)
	return new Date(year ?? 2000, (month ?? 1) - 1, day ?? 1)
}

export function syncToday() {
	const now = new Date()
	today.value = new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

const monthFormat = new Intl.DateTimeFormat('en-US', { month: 'long' })
const weekdayFormat = new Intl.DateTimeFormat('en-US', { weekday: 'long' })
const longFormat = new Intl.DateTimeFormat('en-US', { month: 'long', day: 'numeric', year: 'numeric' })

export const monthName = (date: Date) => monthFormat.format(date)
export const weekdayName = (date: Date) => weekdayFormat.format(date)
export const longDate = (date: Date) => longFormat.format(date)

// The same month and day, some years back. Feb 29 falls back to Feb 28 in years without one, as the app does.
export function yearsAgo(date: Date, years: number) {
	const year = date.getFullYear() - years
	const lastDay = new Date(year, date.getMonth() + 1, 0).getDate()
	return new Date(year, date.getMonth(), Math.min(date.getDate(), lastDay))
}

const monthDayFormat = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' })
const relativeFormat = new Intl.RelativeTimeFormat('en-US', { numeric: 'always' })

export const monthDay = (date: Date) => monthDayFormat.format(date)

// "5 years ago", as the widgets say it: whole years since the photo, or months when it's under a year.
export function relativeAgo(date: Date, now: Date) {
	let months = (now.getFullYear() - date.getFullYear()) * 12 + now.getMonth() - date.getMonth()
	if (now.getDate() < date.getDate()) {
		months -= 1
	}
	return months >= 12 ? relativeFormat.format(-Math.floor(months / 12), 'year') : relativeFormat.format(-Math.max(1, months), 'month')
}
