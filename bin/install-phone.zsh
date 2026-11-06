#!/bin/zsh
# Builds Release for the iPhone, signed with the shared App Store Connect key (the ASC_* lines in fastlane/.env), then
# installs and launches it. Xcode's own DerivedData, so it's as quick as a normal build.
#   bin/install-phone.zsh [device]    the device is a UDID or name; Kyle's Phone by default
set -euo pipefail

root=${0:A:h:h}
cd $root
device=${1:-00008150-001A03003439401C}
project='Photos On This Day.xcodeproj'
scheme='Photos On This Day'
bundle_id=is.ky.Photos-On-This-Day

source <(grep '^ASC_' fastlane/.env | sed 's/^/export /')
key_path=${~ASC_KEY_PATH}

build_args=(-project $project -scheme $scheme -configuration Release -destination "id=$device")
log=$(mktemp)
echo "Building Release…"
if ! xcodebuild $build_args -allowProvisioningUpdates -authenticationKeyPath $key_path -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID $ASC_ISSUER_ID build > $log 2>&1; then
	grep -E 'error:' $log | sort -u >&2 || tail -30 $log >&2
	echo "Build failed; full log at $log" >&2
	exit 1
fi
rm $log

products=$(xcodebuild $build_args -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
echo "Installing on $device…"
xcrun devicectl device install app --device $device "$products/Photos On This Day.app" > /dev/null
xcrun devicectl device process launch --device $device $bundle_id > /dev/null
echo "Installed and launched."
