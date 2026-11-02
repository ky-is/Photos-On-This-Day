#!/bin/zsh
# Mac App Store screenshots, 2880 x 1800 (the window at 1440 x 900 points on a Retina display), into
# fastlane/screenshots/raw/Mac-*.jpg, for bin/app-store-screenshots.zsh to caption (--only captions), which also needs its
# iPad widgets shot for the widgets beside the window. Same day and photos as
# the iOS ones (bin/screenshot-support.zsh), but a Mac app can only read the Mac's own library, so a Debug build shows the
# screenshot photos instead (Shared/ScreenshotLibrary.swift): this serves them, redated, on localhost, where the app
# downloads them. The app opens in the background (open -g), never in front, and each shot is its window alone.
set -euo pipefail

root=${0:A:h:h}
cd $root
source $root/bin/screenshot-support.zsh
scheme='Photos On This Day'
out=$root/fastlane/screenshots/raw
work=$(mktemp -d)
port=8731
server=
app_pid=

stop_app() {
	[[ -n $app_pid ]] && kill $app_pid 2>/dev/null || true
	app_pid=
}
trap 'stop_app; [[ -n $server ]] && kill $server 2>/dev/null; rm -rf $work' EXIT

# NAME:LAUNCH ARGUMENTS, in App Store order: the day with its map, three photos across (each year has about three), then sharing the day as a slideshow video, paused on its
# third photo
shots=(
	"day:-dismissedAddWidget YES -showsDayMap YES -gridThumbnailWidth 576"
	"share-video:-dismissedAddWidget YES -screenshotCollage YES -screenshotCollageFormat video -screenshotCollageSlide 2"
)

check_screenshot_photos
echo 'Building…'
xcodebuild -project $project_file -scheme $scheme -configuration Debug -destination 'platform=macOS' -quiet build
products=$(xcodebuild -project $project_file -scheme $scheme -configuration Debug -destination 'platform=macOS' -showBuildSettings 2>/dev/null | awk '$1 == "BUILD_DIR" { print substr($0, index($0, "=") + 2); exit }')
app="$products/Debug/Photos On This Day.app"

swift $root/bin/redate-photos.swift 06-22 $work/photos $photos_folder/${^photos}.avif > /dev/null
print -l ${^photos}.jpg > $work/photos/index.txt
python3 -I -m http.server $port --bind 127.0.0.1 --directory $work/photos > /dev/null 2>&1 &
server=$!
sleep 1

# The app's window once it's 1440 x 900 points (App/ScreenshotSupport.swift sizes it), as a window number for screencapture -l
window_id() {
	swift - $1 <<-'SWIFT'
		import CoreGraphics
		let pid = Int(CommandLine.arguments[1])!
		let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[CFString: Any]] ?? []
		let window = windows.first { window in
			let bounds = window[kCGWindowBounds] as? [String: Double] ?? [:]
			return window[kCGWindowOwnerPID] as? Int == pid && window[kCGWindowLayer] as? Int == 0 && bounds["Width"] == 1440 && bounds["Height"] == 900
		}
		if let window { print(window[kCGWindowNumber] as! Int) }
	SWIFT
}

# Saves the window once it keeps still (three frames the same), as a JPEG without alpha, which App Store Connect wants
capture() {
	local file=$1 id= previous= frame index same=0
	for index in {1..60}; do
		id=$(window_id $app_pid)
		[[ -n $id ]] && break
		sleep 0.5
	done
	[[ -n $id ]] || { echo "  no window" >&2; exit 1 }
	sleep 4
	for index in {1..60}; do
		frame=$work/frame-$index.png
		screencapture -x -o -l $id $frame
		if [[ -n $previous ]] && cmp -s $previous $frame; then
			(( ++same >= 2 )) && break
		else
			same=0
		fi
		previous=$frame
		sleep 0.5
	done
	(( index < 60 )) || echo "  never kept still, taking the last frame" >&2
	sips -g pixelWidth -g pixelHeight $frame | awk 'NR > 1 { printf "  %s %s\n", $1, $2 }'
	sips -s format jpeg -s formatOptions best $frame --out $file > /dev/null
	rm -f $work/frame-*.png(N)
}

mkdir -p $work/Mac $out
index=1
for shot in $shots; do
	name=${shot%%:*}
	pkill -f "$app/Contents/MacOS/" 2>/dev/null || true
	open -g -n -a $app --args -screenshotPhotos http://127.0.0.1:$port/ -screenshotDate $screenshot_day ${=shot#*:}
	sleep 2
	app_pid=$(pgrep -n -f "$app/Contents/MacOS/")
	# The video takes a while to make
	[[ $shot == *screenshotCollageFormat* ]] && sleep 20
	capture $work/Mac/Mac-$index-$name.jpg
	echo "  Mac-$index-$name.jpg"
	stop_app
	sleep 1
	(( index++ ))
done
rm -f $out/Mac-*.jpg(N)
mv $work/Mac/*.jpg $out/
echo "Saved in $out"
