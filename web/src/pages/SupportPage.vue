<script setup vapor lang="ts">
import ProseLayout from '../components/ProseLayout.vue'
import { APP_STORE_URL, GITHUB_URL } from '../pages'
</script>

<template>
	<ProseLayout eyebrow="Support" title="Need a hand?" lede="Answers to common questions about Photos On This Day, and how to reach us.">
		<h2>Add a widget</h2>
		<h3>On iPhone and iPad</h3>
		<ol>
			<li>Touch and hold an empty spot on your Home Screen until the apps jiggle.</li>
			<li>Tap <strong>Edit</strong> in the top‑left corner, then <strong>Add Widget</strong>.</li>
			<li>Search for “On This Day”, or find it in the list.</li>
			<li>Swipe to choose a size, then tap <strong>Add Widget</strong>.</li>
		</ol>
		<p>To choose which years it shows, or only show favorites, touch and hold the widget and tap <strong>Edit Widget</strong>.</p>
		<h3>On Mac</h3>
		<ol>
			<li>Control‑click an empty spot on your desktop and choose <strong>Edit Widgets</strong>.</li>
			<li>Search for “On This Day”, or find it in the list.</li>
			<li>Choose a size, then drag the widget onto your desktop or into Notification Center.</li>
		</ol>
		<p class="note"><strong>Tip:</strong> if your library is sparse, the widget works best in a Smart Stack. Drag a Photos widget of the same size on top of it: On This Day shows on days with photos, and the Photos widget shows otherwise.</p>

		<h2>Questions</h2>
		<h3>Why can’t I open a photo in the Photos app?</h3>
		<p>Apple doesn’t let apps open the Photos app to a particular photo, so there’s no way to jump from On This Day to the same photo there. You can still favorite, share, hide or delete it right in the app’s viewer.</p>
		<h3>Why don’t I see any photos today?</h3>
		<p>The app shows photos whose date matches today in past years. If you didn’t take any, it points you to nearby days that have some.</p>
		<h3>How do I see another day?</h3>
		<p>On iPhone and iPad, swipe left or right, use the arrows, or tap the calendar to pick any date. On Mac, use the arrows or <strong>⌘[</strong> and <strong>⌘]</strong>, or click the calendar.</p>
		<h3>Why are some photos missing?</h3>
		<p>Screenshots and photos shared with you in iCloud can be turned on in the <strong>Filters</strong> menu, and <strong>Hide Albums</strong> leaves out whole albums. Check too that the app can see your <strong>whole</strong> library, in Settings › Privacy &amp; Security › Photos: if you only allowed some photos, only those appear. Photos stored only in iCloud may take a moment to download.</p>
		<h3>How do I hide a photo, or bring it back?</h3>
		<p>Open the photo and choose <strong>Hide</strong>. To bring it back, use <strong>Restore</strong> at the bottom of that day, or open the About screen and choose <strong>Hidden photos</strong>.</p>
		<h3>How do I change how often the widget changes photo?</h3>
		<p>On iPhone and iPad, touch and hold the widget and choose <strong>Edit Widget</strong>. On Mac, Control‑click it and choose <strong>Edit</strong>. Then pick how often it changes. You can also add a button that shuffles to another photo.</p>
		<h3>Can I get a reminder every day?</h3>
		<p>Turn on <strong>Daily Reminder</strong> in the Filters menu for a notification each morning on days with photos from past years.</p>
		<h3>Can I see this year’s photos too, or the oldest first?</h3>
		<p>Turn on <strong>Show This Year</strong> or <strong>Oldest First</strong> in the Filters menu.</p>
		<h3>Can I use Siri?</h3>
		<p>Yes. Ask Siri to show today’s photos, photos from a chosen year, or a random memory, or find these actions in the Shortcuts app.</p>
		<h3>Does the app collect my data?</h3>
		<p>No. Your photos never leave your device. There’s no account, no tracking and no ads. See the <a href="/privacy/">privacy policy</a>.</p>

		<h2>Get in touch</h2>
		<p>Found a bug or have an idea? <a :href="`${GITHUB_URL}/issues`">Open an issue on GitHub</a>. If you enjoy the app, a <a :href="`${APP_STORE_URL}?action=write-review`">rating on the App Store</a> helps a lot.</p>
	</ProseLayout>
</template>
