# Shared by bin/app-store-screenshots.zsh and bin/duo-screenshots.zsh (sourced): the screenshot photos, and the Today View with
# the app's widgets. Each function takes the simulator's UDID first; $screenshot_support_work is a scratch folder.

support_root=${0:A:h:h}
project_file="$support_root/Photos On This Day.xcodeproj"
bundle_id=is.ky.Photos-On-This-Day

# Every shot is of one day, June 22, 2026, showing photos from the ky.is site: copies moved to June 22 of their own year
# (bin/redate-photos.swift), added to the simulator's library once and left there. None has people in it; 2019 to 2024, in
# the order each year shows them. The widgets pick theirs by place in this list (ScreenshotWidgets in
# Widget/PhotosOnThisDayWidget.swift), so keep the two in step.
photos_folder=~/Documents/Programming/ky.is/ky.is/site/public/photos
photos=(
	post-viaduct-waterfront
	grand-canyon-sunset adventure-cat navajo-nation double-arch
	reflection-lake alta-valley fly-agaric anemones
	crystal-ridge_2
	rocky-mountain-national-park_1 marsha-in-the-window hood-river-spring
	Devereux-low-tide_1 Hope-Ranch-cliffs_1 Hope-Ranch-cliffs_2
)
# After the newest photos, so every year counts as past
screenshot_day=2026-06-22T18:00:00Z

check_screenshot_photos() {
	[[ -d $photos_folder ]] || { echo "No photos at $photos_folder" >&2; exit 1 }
}

# add_screenshot_photos UDID: adds the June 22 copies of the photos to the simulator's library, unless an earlier run did.
# Photos keeps the library in Photos.sqlite, read here only to count them.
add_screenshot_photos() {
	local device=$1 index
	local library=~/Library/Developer/CoreSimulator/Devices/$device/data/Media/PhotoData/Photos.sqlite
	count_on_day() { sqlite3 -readonly $library "select count(*) from ZASSET where ZTRASHEDSTATE = 0 and strftime('%m-%d', ZDATECREATED + 978307200, 'unixepoch', 'localtime') = '06-22'" 2>/dev/null || echo 0 }
	(( $(count_on_day) >= ${#photos} )) && return 0
	echo "  adding ${#photos} photos on June 22 to the library"
	rm -rf $screenshot_support_work/photos
	# In order, so each year's photos keep it
	swift $support_root/bin/redate-photos.swift 06-22 $screenshot_support_work/photos $photos_folder/${^photos}.avif > /dev/null
	xcrun simctl addmedia $device $screenshot_support_work/photos/${^photos}.jpg
	for index in {1..60}; do
		(( $(count_on_day) >= ${#photos} )) && return 0
		sleep 1
	done
	echo "  only $(count_on_day) of ${#photos} photos showed up on June 22" >&2
	exit 1
}

# hand_widgets_the_day UDID: the app hands its day to the widgets and reloads them (App/ScreenshotSupport.swift)
hand_widgets_the_day() {
	xcrun simctl launch --terminate-running-process $1 $bundle_id -screenshotDate $screenshot_day > /dev/null
	sleep 8
	xcrun simctl terminate $1 $bundle_id 2>/dev/null || true
}

# Restarts SpringBoard, which then reads the Home Screen layout from IconState.plist (killed, so it doesn't save its own first)
restart_springboard() {
	xcrun simctl spawn $1 launchctl kill SIGKILL system/com.apple.SpringBoard 2>/dev/null
}

# set_today_view UDID WIDGET:SIZE...: puts the app's widgets in the Today View, top to bottom (photo or years: small, medium,
# large, extraLarge), saving the layout to put back with restore_today_view. Two of one size would show the same photo.
set_today_view() {
	local device=$1; shift
	local icon_state=~/Library/Developer/CoreSimulator/Devices/$device/data/Library/SpringBoard/IconState.plist
	[[ -f $screenshot_support_work/IconState-$device.plist ]] || cp -p $icon_state $screenshot_support_work/IconState-$device.plist
	python3 -I - $icon_state "$@" <<-'PY'
		import plistlib, sys, uuid
		path, layout = sys.argv[1], sys.argv[2:]
		with open(path, 'rb') as file:
		    state = plistlib.load(file)
		kinds = {'photo': 'PhotosOnThisDayWidget', 'years': 'PhotosOnThisDayYearsWidget'}
		def widget(spec):
		    kind, size = spec.split(':')
		    return {'widgetIdentifier': kinds[kind], 'elementType': 'widget', 'iconType': 'custom', 'gridSize': size, 'containerBundleIdentifier': 'is.ky.Photos-On-This-Day', 'bundleIdentifier': 'is.ky.Photos-On-This-Day.Photos-On-This-Day-Widget', 'displayIdentifier': str(uuid.uuid4()).upper(), 'uniqueIdentifier': str(uuid.uuid4()).upper(), 'allowsSuggestions': False, 'allowsExternalSuggestions': False}
		state['today'] = [widget(spec) for spec in layout]
		with open(path, 'wb') as file:
		    plistlib.dump(state, file, fmt=plistlib.FMT_BINARY)
	PY
	restart_springboard $device
}

# restore_today_view UDID: puts back the layout set_today_view saved, if it changed one
restore_today_view() {
	local device=$1
	local saved=$screenshot_support_work/IconState-$device.plist
	[[ -f $saved ]] || return 0
	cp -p $saved ~/Library/Developer/CoreSimulator/Devices/$device/data/Library/SpringBoard/IconState.plist
	rm $saved
	restart_springboard $device
}

# show_today_view UDID: a UI test (UITests/TodayViewScreenshotTests.swift, from build-for-testing) waits for SpringBoard,
# swipes to the Today View and holds it there; this returns once it shows, with the test's pid in $today_view_runner.
# Stop it with hide_today_view. Not on an iPhone Duo, whose screens XCTest's touches don't reach.
show_today_view() {
	local device=$1 log=$screenshot_support_work/today-view.log index
	TEST_RUNNER_TODAY_VIEW_HOLD=180 xcodebuild -project $project_file -scheme 'Photos On This Day' -configuration Debug -destination "id=$device" -only-testing:'Photos On This Day UI Tests/TodayViewScreenshotTests/testShowTodayView' test-without-building > $log 2>&1 &
	today_view_runner=$!
	for index in {1..180}; do
		grep -q 'TODAY VIEW SHOWN' $log && return 0
		kill -0 $today_view_runner 2>/dev/null || { cat $log >&2; echo "  the Today View test stopped early" >&2; exit 1 }
		sleep 1
	done
	kill $today_view_runner
	echo "  the Today View never showed" >&2
	exit 1
}

hide_today_view() {
	[[ -n ${today_view_runner:-} ]] || return 0
	kill $today_view_runner 2>/dev/null
	wait $today_view_runner 2>/dev/null || true
	today_view_runner=
}
