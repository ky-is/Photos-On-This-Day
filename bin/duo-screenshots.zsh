# Duo hinge-pose screenshots: run `duo-screenshots` from the repo (bin/app-store-screenshots.zsh runs it for the App Store
# Duo shots). The day the App Store shots show, June 22, with the photos in bin/screenshot-support.zsh.
source ${0:A:h}/screenshot-support.zsh
project='Photos On This Day.xcodeproj'
scheme='Photos On This Day'
title='Photos On This Day'

# The day, without the Add a Widget button, as if it had been dismissed, with the map of its photos pinned at the bottom
day() {
	# The tool's scratch folder, which it makes after reading this
	screenshot_support_work=$WORK
	# Access up front (the app was just reinstalled), so no permission alert covers the photos
	xcrun simctl privacy $device grant photos $bundle_id
	add_screenshot_photos $device
	launch -screenshotDate $screenshot_day -dismissedAddWidget YES -showsDayMap YES
	shoot day
}

# The full-screen viewer, opened on the day's first portrait photo once the grid has loaded (not an App Store shot)
viewer() {
	screenshot_support_work=$WORK
	xcrun simctl privacy $device grant photos $bundle_id
	add_screenshot_photos $device
	launch -screenshotDate $screenshot_day -dismissedAddWidget YES -screenshotViewer YES
	sleep 2
	shoot viewer
}

duo_shots() { shots day day; shots viewer viewer }
