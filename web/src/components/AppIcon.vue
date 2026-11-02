<script setup vapor lang="ts">
const { size = 48 } = defineProps<{ size?: number }>()
</script>

<template>
	<img class="app-icon" src="/icon.png" alt="" :width="size" :height="size" />
</template>

<style scoped>
.app-icon {
	border-radius: 22.37%;
	box-shadow:
		0 0 0 0.5px oklch(0 0 0 / 0.08),
		0 4px 12px -4px oklch(0.25 0.06 330 / 0.4);
	corner-shape: superellipse(1.6);
}
</style>
