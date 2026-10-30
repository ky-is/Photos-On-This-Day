#!/bin/zsh
# App Store screenshots for the display sizes App Store Connect requires; it scales them for the other sizes:
#   iPhone with Dynamic Island (medium display), 1206 x 2622, on an iPhone 18 Pro
#   iPad 13-inch display, 2064 x 2752, on an iPad Pro 13-inch (M5)
# (Heart Beats also makes iPhone Duo ones, required from April 2027, with duo-screenshots; not here yet.)
# --only "iPhone iPad" picks some of them (both by default).
# Run with `fastlane screenshots`, or directly. Writes fastlane/screenshots/en-US/, where deliver finds them.
# Each device is the shared simulator for its type (shared-sim, see ~/.claude/CLAUDE.md), waited for while something else
# uses it, then given back still booted and as it was found.
# The simulator build shows the simulator's built-in sample library, on the day -screenshotDate picks (August 8, with
# three 2012 waterfall photos); Debug, for the -screenshotViewer launch argument (App/ScreenshotSupport.swift).
set -euo pipefail

root=${0:A:h:h}
cd $root
project="$root/Photos On This Day.xcodeproj"
scheme='Photos On This Day'
bundle_id=is.ky.Photos-On-This-Day
out=$root/fastlane/screenshots/en-US
# The products folder of Xcode's own DerivedData, the same one a normal build uses
products_dir() { xcodebuild -project $project -scheme $1 -configuration $2 -destination $3 -showBuildSettings 2>/dev/null | awk '$1 == "BUILD_DIR" { print substr($0, index($0, "=") + 2); exit }' }
work=$(mktemp -d)
device=
appearance=
only=(iPhone iPad)
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
	xcrun simctl terminate $device $bundle_id 2>/dev/null || true
	xcrun simctl status_bar $device clear 2>/dev/null || true
	[[ -n $appearance ]] && xcrun simctl ui $device appearance $appearance 2>/dev/null || true
	shared-sim release $device
	device=
}
trap 'release_device; rm -rf $work' EXIT

# replace_set NAME FOLDER: the new NAME-* shots in FOLDER replace the old ones. One that looks the same as the shot it
# replaces (no pixel off by more than 3%) keeps the old file, so its checksum still matches what App Store Connect has and
# `fastlane upload_screenshots` leaves it alone; a fresh capture is a new JPEG even when nothing on screen changed.
replace_set() {
	local name=$1 folder=$2 new old kept=0
	for new in $folder/$name-*.jpg; do
		old=$out/${new:t}
		if [[ -f $old ]] && [[ $(magick compare -metric AE -fuzz 3% $old $new null: 2>&1 | awk '{print $1}') == 0 ]]; then
			cp -p $old $new
			(( ++kept ))
		fi
	done
	rm -f $out/$name-*.jpg(N)
	mv $folder/$name-*.jpg $out/
	(( kept )) && echo "  $name: $kept unchanged, kept as they were"
	return 0
}

# NAME:DEVICE TYPE
devices=(
	iPhone:com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro
	iPad:com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
)
# NAME:LAUNCH ARGUMENTS, in App Store order
day='-screenshotDate 2022-08-08T18:00:00Z'
shots=(
	"day:$day"
	"viewer:$day -screenshotViewer YES"
)

echo 'Building…'
xcodebuild -project $project -scheme $scheme -configuration Debug -destination 'generic/platform=iOS Simulator' -quiet build
app=$(products_dir "$scheme" Debug 'generic/platform=iOS Simulator')/Debug-iphonesimulator/Photos\ On\ This\ Day.app

# Saves the screen once it keeps still (three frames the same, a while after launch, so the photos and the viewer have
# loaded). A blank screen (the launch screen) or a spinner is mostly one flat color, a small PNG, so it doesn't count.
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
	# The new set goes beside the old one, which it replaces only once every shot is taken, so a failed run leaves it alone
	fresh=$work/$name
	mkdir -p $fresh
	index=1
	for shot in $shots; do
		shot_name=${shot%%:*}
		xcrun simctl launch --terminate-running-process $device $bundle_id ${=shot#*:} > /dev/null
		# After each launch: an override set right after boot is recorded but not always drawn
		xcrun simctl status_bar $device override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
		capture $device $fresh/$name-$index-$shot_name.jpg
		echo "  $name-$index-$shot_name.jpg"
		(( index++ ))
	done
	replace_set $name $fresh
	release_device
done
echo "Saved in $out"
