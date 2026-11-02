<script setup vapor lang="ts">
import SiteFooter from './components/SiteFooter.vue'
import SiteHeader from './components/SiteHeader.vue'
import type { PageName } from './pages'
import HomePage from './pages/HomePage.vue'
import PrivacyPage from './pages/PrivacyPage.vue'
import SupportPage from './pages/SupportPage.vue'

const { page } = defineProps<{ page: PageName }>()
</script>

<template>
	<a class="skip" href="#main">Skip to content</a>
	<SiteHeader :page="page" />
	<main id="main">
		<HomePage v-if="page === 'home'" />
		<PrivacyPage v-else-if="page === 'privacy'" />
		<SupportPage v-else />
	</main>
	<SiteFooter />
</template>
