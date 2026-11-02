<script setup vapor lang="ts">
import ProseLayout from '../components/ProseLayout.vue'
import { GITHUB_URL } from '../pages'
</script>

<template>
	<ProseLayout eyebrow="Privacy policy" title="We collect nothing." lede="Photos On This Day has no ads, no analytics, no accounts and no servers. Your photos never leave your device.">
		<h2>Your photo library</h2>
		<p>The app asks for access to your photo library so it can show you photos from this day in past years. It reads your library on your device, through Apple’s Photos framework, and never uploads, copies or sends your photos anywhere.</p>
		<p>When you delete or favorite a photo from the viewer, the app asks Photos to make that change, and Photos asks you to confirm it.</p>
		<h2>Widgets, Siri and notifications</h2>
		<p>Widgets, Siri and Shortcuts read the same library on your device. Notifications, such as the occasional reminder on a day with lots of photos, are scheduled on your device by the app itself. There is no push notification server.</p>
		<h2>Settings</h2>
		<p>Your preferences, such as which photos to hide or how often widgets change, are stored on your device. If you use iCloud, Apple may back them up along with your other app data, under Apple’s own privacy policy.</p>
		<h2>No tracking</h2>
		<p>The app contains no advertising, no analytics and no third‑party code that collects data. It doesn’t track you across apps or websites, and its App Store listing says <strong>Data Not Collected</strong>.</p>
		<p>This website doesn’t use cookies or analytics either.</p>
		<h2>Open source</h2>
		<p>You don’t have to take our word for it: the <a :href="GITHUB_URL">source code is on GitHub</a>.</p>
		<p class="note">Questions? <a :href="`${GITHUB_URL}/issues`">Open an issue on GitHub</a>. Last updated October 31, 2026.</p>
	</ProseLayout>
</template>
