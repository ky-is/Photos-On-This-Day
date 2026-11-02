#!/bin/zsh
# App Store screenshots for the display sizes App Store Connect requires; it scales them for the other sizes:
#   iPhone with Dynamic Island (medium display), 1206 x 2622, on an iPhone 18 Pro
#   iPad 13-inch display, 2064 x 2752, on an iPad Pro 13-inch (M5)
#   iPhone Duo, inner 2007 x 2853 then cover 2034 x 1398 (required from April 2027): the day from duo-screenshots
#   (bin/duo-screenshots.zsh), open then closed. Its widgets shot, Duo-1-widgets.jpg, is taken by hand and kept as it is:
#   XCTest's touches don't reach the Duo's screens, so nothing here can swipe to its Today View (see the end of this file).
# --only "iPhone iPad Duo" picks some of them (all by default); --only captions just redraws the captions.
# Run with `fastlane screenshots`, or directly. The screens as captured go in fastlane/screenshots/raw/, and the captioned
# ones App Store Connect gets (bin/caption-screenshots.swift), one set per language of fastlane/metadata, in
# fastlane/screenshots/<locale>/, where the upload finds them. The screens are the same English ones in every language.
# Each device is the shared simulator for its type (shared-sim, see ~/.claude/CLAUDE.md), waited for while something else
# uses it, then given back still booted and as it was found.
# Every shot is of June 22, 2026, with the photos in bin/screenshot-support.zsh; Debug simulator build, for -screenshotDate
# (App/ScreenshotSupport.swift). The widgets shot comes first: the Today View with the small, medium and large widgets (it
# has no room for extra large), the Home Screen layout put back afterwards. A UI test (UITests/TodayViewScreenshotTests.swift)
# swipes to the Today View.
set -euo pipefail

root=${0:A:h:h}
cd $root
source $root/bin/screenshot-support.zsh
project=$project_file
scheme='Photos On This Day'
out=$root/fastlane/screenshots/raw
screenshots=$root/fastlane/screenshots
# The products folder of Xcode's own DerivedData, the same one a normal build uses
products_dir() { xcodebuild -project $project -scheme $1 -configuration $2 -destination $3 -showBuildSettings 2>/dev/null | awk '$1 == "BUILD_DIR" { print substr($0, index($0, "=") + 2); exit }' }
work=$(mktemp -d)
screenshot_support_work=$work
device=
appearance=
only=(iPhone iPad Duo)
while (( $# )); do
	case $1 in
		--only) only=(${=2}); shift ;;
		*) echo "Unknown option $1" >&2; exit 2 ;;
	esac
	shift
done
wants() { (( ${only[(Ie)$1]} )) }

# Puts back what this changed on the shared simulator and gives it back, still booted (marked idle), so the next run
# doesn't have to boot it from scratch
release_device() {
	[[ -n $device ]] || return 0
	hide_today_view
	restore_today_view $device
	xcrun simctl terminate $device $bundle_id 2>/dev/null || true
	xcrun simctl status_bar $device clear 2>/dev/null || true
	[[ -n $appearance ]] && xcrun simctl ui $device appearance $appearance 2>/dev/null || true
	shared-sim release $device
	device=
}
trap 'release_device; rm -rf $work' EXIT

# replace_set NAME FOLDER [KEEP]: the new NAME-* shots in FOLDER replace the old ones, apart from KEEP (a file name, left
# alone). One that looks the same as the shot it replaces (no pixel off by more than 3%) keeps the old file, so its checksum
# still matches what App Store Connect has and `fastlane upload_screenshots` leaves it alone; a fresh capture is a new JPEG
# even when nothing on screen changed.
replace_set() {
	local name=$1 folder=$2 keep=${3:-} new old kept=0 stale
	for new in $folder/$name-*.jpg; do
		old=$out/${new:t}
		if [[ -f $old ]] && [[ $(magick compare -metric AE -fuzz 3% $old $new null: 2>&1 | awk '{print $1}') == 0 ]]; then
			cp -p $old $new
			(( ++kept ))
		fi
	done
	for stale in $out/$name-*.jpg(N); do
		[[ ${stale:t} == $keep ]] || rm $stale
	done
	mv $folder/$name-*.jpg $out/
	(( kept )) && echo "  $name: $kept unchanged, kept as they were"
	return 0
}

# NAME:DEVICE TYPE
devices=(
	iPhone:com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro
	iPad:com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
)
# The Today View's widgets for the widgets shot (WIDGET:SIZE, top to bottom)
today_view=(photo:small years:medium photo:large)
# NAME:LAUNCH ARGUMENTS, in App Store order after the widgets shot. The day without the Add a Widget button, as if it had
# been dismissed, and with the map of where its photos were taken pinned at the bottom. Then sharing the day as a
# slideshow video, paused on its third photo (the mountain reflected in a lake).
shots=(
	"day:-screenshotDate $screenshot_day -dismissedAddWidget YES -showsDayMap YES"
	"share-video:-screenshotDate $screenshot_day -dismissedAddWidget YES -screenshotCollage YES -screenshotCollageFormat video -screenshotCollageSlide 2"
)

if wants iPhone || wants iPad; then
	check_screenshot_photos
	echo 'Building…'
	# The app and the UI tests, for the Today View
	xcodebuild -project $project -scheme $scheme -configuration Debug -destination 'generic/platform=iOS Simulator' -quiet build-for-testing
	app=$(products_dir "$scheme" Debug 'generic/platform=iOS Simulator')/Debug-iphonesimulator/Photos\ On\ This\ Day.app
fi

# Saves the screen once it keeps still (three frames the same, a while after launch, so the photos have loaded). A blank
# screen (the launch screen) or a spinner is mostly one flat color, a small PNG, so it doesn't count.
capture() {
	local device=$1 file=$2 previous= frame index same=0
	sleep 3
	for index in {1..60}; do
		frame=$work/frame-$index.png
		xcrun simctl io $device screenshot $frame > /dev/null 2>&1
		if [[ -n $previous ]] && (( $(stat -f %z $frame) > 300000 )) && cmp -s $previous $frame; then
			(( ++same >= 2 )) && break
		else
			same=0
		fi
		previous=$frame
		sleep 0.5
	done
	(( index < 60 )) || echo "  never kept still, taking the last frame" >&2
	# App Store Connect rejects images with an alpha channel
	sips -s format jpeg -s formatOptions best $frame --out $file > /dev/null
	rm -f $work/frame-*.png(N)
}

# 9:41 on the screenshot day, in this Mac's time zone (the simulator's) on that date, so iPad's status bar, which shows the
# date too, matches the day the app shows
status_bar_time() {
	local day=${screenshot_day%%T*} offset
	offset=$(date -j -f '%Y-%m-%d %H:%M' "$day 09:41" +%z)
	# simctl only takes it with milliseconds and a colon in the offset
	echo "${day}T09:41:00.000${offset[1,3]}:${offset[4,5]}"
}

# Everything at once, then (status_bar_weekday, a few seconds later) the time again on its own: when the last override
# that sets the time sets other values too, simctl shows the wrong weekday for the date on iPad. Sent back to back, the
# second can leave the status bar hidden.
status_bar() {
	xcrun simctl status_bar $device override --time $(status_bar_time) --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
}

status_bar_weekday() {
	xcrun simctl status_bar $device override --time $(status_bar_time)
}

mkdir -p $out

for entry in $devices; do
	name=${entry%%:*}
	kind=${entry#*:}
	wants $name || continue
	udid=$(shared-sim udid $kind)
	echo "$name: $(xcrun simctl list devices | grep $udid | sed -E 's/^ +//; s/ \(.*//')…"
	shared-sim acquire $udid 'Photos On This Day App Store screenshots'
	device=$udid
	# Left booted by the last run, it needn't boot again
	xcrun simctl list devices | grep -q "($device) (Booted)" || xcrun simctl boot $device
	xcrun simctl bootstatus $device -b > /dev/null
	appearance=$(xcrun simctl ui $device appearance)
	xcrun simctl ui $device appearance light
	xcrun simctl uninstall $device $bundle_id 2>/dev/null || true
	xcrun simctl install $device $app
	# Photos access up front, so no permission alert or onboarding screen covers the photos
	xcrun simctl privacy $device grant photos $bundle_id
	add_screenshot_photos $device
	# The new set goes beside the old one, which it replaces only once every shot is taken, so a failed run leaves it alone
	fresh=$work/$name
	mkdir -p $fresh
	hand_widgets_the_day $device
	set_today_view $device $today_view
	show_today_view $device
	status_bar
	# Time for the widgets to draw their photos: until then they show placeholders, which keep still too
	sleep 10
	status_bar_weekday
	capture $device $fresh/$name-1-widgets.jpg
	echo "  $name-1-widgets.jpg"
	hide_today_view
	# The Home Screen goes back in release_device, after the other shots: restarting SpringBoard now would leave them
	# without a status bar
	index=2
	for shot in $shots; do
		shot_name=${shot%%:*}
		xcrun simctl launch --terminate-running-process $device $bundle_id ${=shot#*:} > /dev/null
		# After each launch, once the app has settled: an override set right after boot is recorded but not always drawn,
		# and one set while the app is still launching can leave the status bar hidden
		sleep 4
		# The video takes a while to make, and its progress bar can hold still long enough to pass for the finished screen
		[[ $shot == *screenshotCollageFormat* ]] && sleep 20
		status_bar
		sleep 3
		status_bar_weekday
		capture $device $fresh/$name-$index-$shot_name.jpg
		echo "  $name-$index-$shot_name.jpg"
		(( index++ ))
	done
	replace_set $name $fresh
	release_device
done

# iPhone Duo: the day open (inner screen, portrait) then closed (cover screen), from bin/duo-screenshots.zsh, after the
# widgets shot taken by hand. A throwaway open pose goes first: the first pose after boot comes out in the boot orientation.
if wants Duo; then
	[[ -f $out/Duo-1-widgets.jpg ]] || echo "  no Duo-1-widgets.jpg: take it by hand (the end of this file says how)" >&2
	duo-screenshots --no-build --keep --poses 'open open-tall closed' --only day
	mkdir -p $work/Duo
	index=2
	for pose in open-tall closed; do
		shot=($root/build/duo-screenshots/$pose/day-*.png(N))
		[[ -n ${shot[1]:-} ]] || { echo "No Duo $pose day shot" >&2; exit 1 }
		sips -s format jpeg -s formatOptions best $shot[1] --out $work/Duo/Duo-$index-$pose-day.jpg > /dev/null
		(( index++ ))
	done
	replace_set Duo $work/Duo Duo-1-widgets.jpg
fi
# The captioned screenshots, drawn from the raw ones, in every language. One that comes out looking the same as before keeps
# the old file, as in replace_set, so `fastlane upload_screenshots` leaves it alone.
echo 'Captioning…'
for locale in $root/fastlane/metadata/*/name.txt(N:h:t); do
	captioned=$work/captioned/$locale
	final=$screenshots/$locale
	mkdir -p $captioned $final
	xcrun swift $root/bin/caption-screenshots.swift $out $captioned $locale
	for file in $captioned/*.jpg; do
		old=$final/${file:t}
		if [[ -f $old ]] && [[ $(magick compare -metric AE -fuzz 3% $old $file null: 2>&1 | awk '{print $1}') == 0 ]]; then
			cp -p $old $file
		fi
	done
	rm -f $final/*.jpg(N)
	mv $captioned/*.jpg $final/
done
echo "Saved in $screenshots"

# The Duo widgets shot, by hand: on the shared iPhone Duo (shared-sim acquire), with the app installed, given photos access
# and the photos added, run hand_widgets_the_day and then set_today_view with photo:small years:medium (the Duo's Today View
# doesn't scroll, and a large widget below those runs off the bottom). Bend it open-tall (sim-hinge from duo-screenshots,
# -position=open -deviceOrientation=landscapeLeft), set the status bar to 9:41, swipe right twice on the inner screen in
# the Simulator app to reach the Today View, save the inner screen (simctl io screenshot --display=<the 2007 x 2853 one>)
# as JPEG to fastlane/screenshots/raw/Duo-1-widgets.jpg, then restore_today_view and shared-sim release.
