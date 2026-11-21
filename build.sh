#!/bin/zsh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Vorssaint

# Builds Tina, assembles the .app bundle, signs it and (with --install)
# installs it into /Applications.
#
# The bundle is staged in a temporary directory outside ~/Documents: folders synced
# by File Provider gain xattrs (com.apple.provenance etc.) that invalidate codesign.
set -euo pipefail
cd "$(dirname "$0")"

# The icon catalog and the bundle are staged in temp dirs; sweep both however
# the script ends.
ICON_TMP=""
STAGE_TMP=""

cleanup() {
    [[ -n "$ICON_TMP" ]] && rm -rf "$ICON_TMP"
    [[ -n "$STAGE_TMP" ]] && rm -rf "$STAGE_TMP"
    return 0
}
trap cleanup EXIT
# zsh runs the EXIT trap when the script is hung up, but not when it is
# interrupted or terminated; route those through exit so a Ctrl-C partway
# into the build sweeps like any other ending.
trap 'exit 1' INT TERM HUP

# Flags: --dev builds the local-only "Tina (Developer)" variant (its own
# bundle id, so it coexists with the official app); --install puts it in /Applications.
DEV=0
INSTALL=0
TEST=0
TEST_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --dev)     DEV=1 ;;
        --install) INSTALL=1 ;;
        --test)    TEST=1 ;;
        --test-suite=*) TEST=1; TEST_ARGS+=("--suite=${arg#*=}") ;;
        --list-tests) TEST=1; TEST_ARGS+=(--list) ;;
    esac
done

if (( DEV )); then
    APP_NAME="Tina (Developer)"
    EXECUTABLE="TinaDeveloper"
    APP_BUNDLE_ID="com.tina.utils.dev"
    BUILD_VARIANT_FLAGS=(-D TINA_DEVELOPMENT)
    APP_OPTIMIZATION_FLAGS=(-Onone)
    BUILD_CONFIGURATION="debug"
else
    APP_NAME="Tina"
    EXECUTABLE="Tina"
    APP_BUNDLE_ID="com.tina.utils"
    BUILD_VARIANT_FLAGS=()
    APP_OPTIMIZATION_FLAGS=(-O)
    BUILD_CONFIGURATION="release"
fi
FAN_HELPER_ID="$APP_BUNDLE_ID.fan-control"
# Now Playing is read through /usr/bin/perl loading this library; see
# Sources/NowPlayingAdapter. Staged under Contents/Frameworks, signed on its own.
NOW_PLAYING_ADAPTER_ID="$APP_BUNDLE_ID.now-playing"
NOW_PLAYING_ADAPTER="libTinaNowPlaying.dylib"
TARGET="arm64-apple-macosx14.0"
ENTITLEMENTS="Resources/Tina.entitlements"
LEGACY_IDENTITY="Tina Utils Signing"

developer_id_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep 'Developer ID Application' \
        | head -1 \
        | sed -E 's/.*"(.*)".*/\1/' || true
}

# A find-identity listing also names certificates codesign then rejects (an
# expired one fails the build with errSecInternalComponent), and -v excludes
# every self-signed one; ask codesign itself with a throwaway copy of /bin/echo.
legacy_identity_installed() {
    local probe signed=1
    # A locked keychain still lists its identities but cannot sign with them,
    # and this one is locked after every reboot; unlock it before asking.
    security unlock-keychain -p tina-signing \
        "$HOME/Library/Keychains/tina-signing.keychain-db" 2>/dev/null || true
    probe="$(mktemp)"
    cp /bin/echo "$probe"
    /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$probe" \
        >/dev/null 2>&1 && signed=0
    rm -f "$probe"
    return $signed
}

# Any build that lands in /Applications needs a stable signature, not just the
# Developer one: macOS ties Accessibility and Screen Recording grants to the
# exact binary hash, so an ad-hoc rebuild orphans them while System Settings
# keeps showing them as granted, and no new prompt ever appears. A plain
# --install strands them under the released bundle id, on the app the user
# actually relies on. When no identity is installed, create the stable local one
# up front instead of falling through to ad-hoc — setup-signing.sh is free,
# offline and idempotent. Gating on the install rather than the variant keeps
# this off CI, where neither ci.yml nor release.yml passes --install.
if (( DEV || INSTALL )) && [[ -z "$(developer_id_identity)" ]] \
    && ! legacy_identity_installed; then
    echo "▸ No signing identity installed; creating the stable local one…"
    if ! ./Tools/setup-signing.sh; then
        echo "  ⚠ Tools/setup-signing.sh failed; signing ad-hoc instead." >&2
        echo "    Accessibility and Screen Recording grants will not survive rebuilds:" >&2
        echo "    System Settings will show them as granted while the app is not trusted." >&2
        echo "    After fixing the identity, clear the stale grant once with:" >&2
        echo "      tccutil reset Accessibility $APP_BUNDLE_ID" >&2
    fi
fi

codesign_with_timestamp_retry() {
    local attempt
    for attempt in 1 2 3; do
        if /usr/bin/codesign "$@"; then
            return 0
        fi
        if (( attempt < 3 )); then
            echo "  Developer ID signing failed; retrying ($((attempt + 1))/3)"
            sleep "$attempt"
        fi
    done
    return 1
}

write_swift_output_file_map() {
    local output_file="$1"
    local object_dir="$2"
    shift 2
    local source artifact

    {
        print -r -- "{"
        print -r -- "  \"\": {"
        print -r -- "    \"swift-dependencies\": \"$object_dir/master.swiftdeps\""
        print -r -- "  }"
        for source in "$@"; do
            artifact="${source//\//__}"
            artifact="${artifact%.swift}"
            print -r -- ","
            print -r -- "  \"$source\": {"
            print -r -- "    \"object\": \"$object_dir/$artifact.o\","
            print -r -- "    \"swift-dependencies\": \"$object_dir/$artifact.swiftdeps\""
            print -r -- "  }"
        done
        print -r -- "}"
    } > "$output_file"
}

finalize_installed_bundle_after_child() {
    local bundle="$1"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
    local devid
    devid="$(developer_id_identity)"

    echo "▸ Finalizing installed signature…"
    sleep 3
    if [[ -n "$devid" ]]; then
        [[ -f "$helper" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
            --options runtime --timestamp --identifier "$FAN_HELPER_ID" --sign "$devid" "$helper"
        [[ -f "$adapter" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
            --options runtime --timestamp --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$devid" "$adapter"
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$devid" "$bundle"
    elif legacy_identity_installed; then
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign "$LEGACY_IDENTITY" "$helper"
        [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$LEGACY_IDENTITY" "$adapter"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$bundle"
    else
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign - "$helper"
        [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign - "$adapter"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign - "$bundle"
    fi
    [[ -f "$helper" ]] && /usr/bin/codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && /usr/bin/codesign --verify --strict "$adapter"
    /usr/bin/codesign --verify --deep --strict "$bundle"
    echo "✓ Signature ready: $bundle"
}

if (( INSTALL && ! TEST )) && [[ "${TINA_INSTALL_CHILD:-0}" != "1" ]]; then
    TINA_INSTALL_CHILD=1 "$0" "$@"
    child_status=$?
    if (( child_status != 0 )); then
        exit "$child_status"
    fi
    finalize_installed_bundle_after_child "/Applications/$APP_NAME.app"
    exit 0
fi

# Prefer the macOS 26 SDK when present: the 27 SDK turns SwiftUI property wrappers
# into macros (SwiftUIMacros plugin) that the Command Line Tools cannot load yet.
PINNED_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    SDK="$(xcrun --show-sdk-path)"
elif [[ -d "$PINNED_SDK" ]]; then
    SDK="$PINNED_SDK"
else
    SDK="$(xcrun --show-sdk-path)"
fi
SDK_COMPAT_FLAGS=()
VM_STATISTICS_COMPAT_FLAGS=(-I Sources/VMStatisticsCompat)
HID_EVENT_SYSTEM_FLAGS=(-I Sources/HIDEventSystem)
CORE_AUDIO_TAP_FLAGS=(-I Sources/CoreAudioTapCompat)
GIF_CODEC_FLAGS=(-I Sources/RecorderGIFCodec)
GIF_CODEC_OBJECTS=(build/objects/recorder-gif-codec/RecorderGIFCodec.o
                   build/objects/recorder-gif-codec/cgif_raw.o)
if [[ "$SDK" == "$PINNED_SDK" ]]; then
    # Swift 6.4 can read the SDK 26 interfaces when given their compiler version.
    SDK_COMPAT_FLAGS=(-Xfrontend -interface-compiler-version -Xfrontend 6.3.2)
fi

# The defaults migrations under test need a real UserDefaults suite, and every
# suite leaves an empty plist in ~/Library/Preferences. The tests already clear
# the domains, but cfprefsd writes the emptied file back out around the time the
# process that owned it exits, so only a caller that outlives the run can remove
# them. `PreferenceNamespaceTests` scans every compiled Swift test file against
# these namespaces, which keeps this sweep complete without a second list.
discard_test_preferences() {
    local preferences="${1:-$HOME/Library/Preferences}" name attempt
    local survivors=0 quiet_passes=0
    # cfprefsd can recreate an emptied domain after the first removal. Require
    # two quiet checks, but keep a hard limit so persistent failures still fail CI.
    for attempt in {1..10}; do
        for name in "vorss.tests." "com.tina.tests."; do
            rm -f "$preferences"/$name*.plist(N)
        done
        rm -f "$preferences/metrics-tests.plist"
        sleep 0.2
        survivors=$(find "$preferences" -maxdepth 1 \
            \( -name "vorss.tests.*.plist" -o -name "com.tina.tests.*.plist" \
               -o -name "metrics-tests.plist" \) 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$survivors" == "0" ]]; then
            quiet_passes=$((quiet_passes + 1))
            if (( quiet_passes == 2 )); then return 0; fi
        else
            quiet_passes=0
        fi
    done
    echo "✗ test preferences did not settle in $preferences ($survivors remaining)" >&2
    return 1
}

# Standalone automated tests: pure contracts plus isolated disk, subprocess,
# keyboard-data and media fixtures. No application windows or device capture.
mkdir -p build/objects/recorder-gif-codec
xcrun clang -O3 -std=c99 -target "$TARGET" -isysroot "$SDK" \
    -c Sources/RecorderGIFCodec/RecorderGIFCodec.c -o "$GIF_CODEC_OBJECTS[1]"
xcrun clang -O3 -std=c99 -target "$TARGET" -isysroot "$SDK" \
    -c Sources/RecorderGIFCodec/vendor/cgif/cgif_raw.c -o "$GIF_CODEC_OBJECTS[2]"

if (( TEST )); then
    python3 Tests/generate_sources.py
    TEST_OBJECT_DIR="build/objects/tests"
    mkdir -p "$TEST_OBJECT_DIR"
    TEST_SOURCES=(
        Sources/Tina/Services/Media/MediaSupport.swift
        Sources/Tina/Core/QuitProtectionSupport.swift
        Sources/Tina/Core/QuitProtectionStrings.swift
        Sources/Tina/Core/Defaults.swift
        Sources/Tina/Core/NotchStrings.swift
        Sources/Tina/Core/NotchTourStrings.swift
        Sources/Tina/Core/NotchEditorStrings.swift
        Sources/Tina/UI/Settings/NotchSettingsTabRow.swift
        Sources/Tina/Core/NotchActivityStrings.swift
        Sources/Tina/Services/Notch/NotchTimerSupport.swift
        Sources/Tina/Services/Notch/NotchAppFullscreen.swift
        Sources/Tina/Services/Notch/NotchTimerAlert.swift
        Sources/Tina/UI/Notch/NotchIslandAlert.swift
        Sources/Tina/Services/Notch/NotchAccessorySupport.swift
        Sources/Tina/Services/Notch/NotchAccessoryConnectionMonitor.swift
        Sources/Tina/Services/QuickTools/CameraPreviewSupport.swift
        Sources/Tina/Core/NotchMusicExtrasStrings.swift
        Sources/Tina/Core/NotchClipboardSizeStrings.swift
        Sources/Tina/Services/Notch/NotchLyricsSupport.swift
        Sources/Tina/Services/Notch/NotchQueueSupport.swift
        Sources/Tina/Services/Notch/NotchPreferredPlayer.swift
        Sources/Tina/Core/NotchFilesStrings.swift
        Sources/Tina/Core/NotchWatchStrings.swift
        Sources/Tina/Services/Notch/NotchWatchSupport.swift
        Sources/Tina/Core/NotchMascotStrings.swift
        Sources/Tina/Services/Notch/NotchMascotSupport.swift
        Sources/Tina/Services/CommandBar/CommandBarDropletMotion.swift
        Sources/Tina/Services/Notch/NotchFileToolsSupport.swift
        Sources/Tina/Services/Notch/NotchDownloadSupport.swift
        Sources/Tina/Services/Notch/NotchDownloadProgressObserver.swift
        Sources/Tina/Core/NotchCalendarStrings.swift
        Sources/Tina/Core/NotchNotificationStrings.swift
        Sources/Tina/Core/NotchGestureStrings.swift
        Sources/Tina/Core/NotchAgentStrings.swift
        Sources/Tina/Core/CodexAccountStrings.swift
        Sources/Tina/Core/ClaudeAccountStrings.swift
        Sources/Tina/Services/Notch/NotchAgentSupport.swift
        Sources/Tina/Core/NotchLockScreenStrings.swift
        Sources/Tina/Services/Notch/NotchLockScreenSupport.swift
        Sources/Tina/Services/AgentUsage/AgentUsageModels.swift
        Sources/Tina/Services/AgentUsage/AgentPricing.swift
        Sources/Tina/Services/AgentUsage/AgentLogObject.swift
        Sources/Tina/Services/AgentUsage/AgentLogParser.swift
        Sources/Tina/Services/AgentUsage/Harness/AgentHarnessReader.swift
        Sources/Tina/Services/AgentUsage/Harness/ClaudeReader.swift
        Sources/Tina/Services/AgentUsage/Harness/CodexReader.swift
        Sources/Tina/Services/AgentUsage/Harness/OpenCodeReader.swift
        Sources/Tina/Services/AgentUsage/Harness/CopilotReader.swift
        Sources/Tina/Services/AgentUsage/AgentUsageSummary.swift
        Sources/Tina/Services/AgentUsage/AgentUsageStore.swift
        Sources/Tina/Services/AgentUsage/AgentUsageArchive.swift
        Sources/Tina/Services/AgentUsage/AgentClaudeAppUsage.swift
        Sources/Tina/Services/AgentUsage/AgentCLIConversation.swift
        Sources/Tina/Services/AgentUsage/AgentClaudeServer.swift
        Sources/Tina/Services/AgentUsage/ClaudeAccountProfile.swift
        Sources/Tina/Services/AgentUsage/AgentCodexServer.swift
        Sources/Tina/Services/AgentUsage/CodexAccountLimits.swift
        Sources/Tina/Services/AgentUsage/CodexProfileLimitsService.swift
        Sources/Tina/Services/AgentUsage/AgentOpenCodeReader.swift
        Sources/Tina/Services/Notch/NotchGestureSupport.swift
        Sources/Tina/Services/Notch/NotchSectionPaging.swift
        Sources/Tina/Services/Notch/NotchSliderEditing.swift
        Sources/Tina/Services/Notch/NotchNotificationSupport.swift
        Sources/Tina/Services/Notch/NotchNotificationReaderCore.swift
        Sources/Tina/Services/Notch/NotchCalendarSupport.swift
        Sources/Tina/Services/Notch/NotchKeepAwakeSupport.swift
        Sources/Tina/Services/Notch/NotchSupport.swift
        Sources/Tina/Services/Notch/NotchMenuBarSpace.swift
        Sources/Tina/Services/Notch/NotchAudioLevelSupport.swift
        Sources/Tina/Services/Notch/NotchVolumeKeyGate.swift
        Sources/Tina/Services/Notch/NotchMusicSupport.swift
        Sources/Tina/UI/Notch/NotchDecorativeClock.swift
        Sources/Tina/Services/Notch/NotchBrowserArtworkSupport.swift
        Sources/Tina/UI/Notch/NotchEqualizerBars.swift
        Sources/Tina/UI/Notch/NotchScrollEdgeFade.swift
        Sources/Tina/UI/Notch/NotchAgentAnimationView.swift
        Sources/Tina/UI/WindowVisibilityReader.swift
        Sources/Tina/Services/Notch/NotchMusicAutomationSupport.swift
        Sources/Tina/Services/Notch/NotchMusicAutomation.swift
        Sources/Tina/Services/Notch/NotchPlaybackSource.swift
        Sources/Tina/Services/Notch/NotchPlaybackCommand.swift
        Sources/Tina/Services/Notch/NotchMusicCommandWriter.swift
        Sources/Tina/Core/FeatureCatalog.swift
        Sources/Tina/Core/FeaturePresets.swift
        Sources/Tina/Core/FeatureHubStrings.swift
        Sources/Tina/Core/NightWarmthStrings.swift
        Sources/Tina/Core/ChargeLimitStrings.swift
        Sources/Tina/Core/MixerScreenSharingStrings.swift
        Sources/Tina/Core/ShortcutSettingsStrings.swift
        Sources/Tina/Core/SwitcherShortcutStrings.swift
        Sources/Tina/Core/SettingsBackupSupport.swift
        Sources/Tina/Core/BackupStrings.swift
        Sources/Tina/Core/SnippetStrings.swift
        Sources/Tina/Core/AlertSoundStrings.swift
        Sources/Tina/Core/BrightnessStrings.swift
        Sources/Tina/Core/MediaImageStrings.swift
        Sources/Tina/Core/QuickToggleStrings.swift
        Sources/Tina/Core/ScreenshotStrings.swift
        Sources/Tina/Core/RecentCaptureStrings.swift
        Sources/Tina/Core/RecorderStrings.swift
        Sources/Tina/Core/RecorderShareStrings.swift
        Sources/Tina/Core/CameraPreviewStrings.swift
        Sources/Tina/Core/WallpaperStrings.swift
        Sources/Tina/Services/Wallpaper/WallpaperSupport.swift
        Sources/Tina/UI/MenuPanel/WallpaperThumbnailView.swift
        Sources/Tina/Core/ScratchpadStrings.swift
        Sources/Tina/Core/LaunchpadStrings.swift
        Sources/Tina/Core/FinderRenameStrings.swift
        Sources/Tina/Core/CommandBarStrings.swift
        Sources/Tina/Core/FeedbackStrings.swift
        Sources/Tina/Core/RadialMenuStrings.swift
        Sources/Tina/Core/MenuBarAppearanceStrings.swift
        Sources/Tina/Core/AppAppearance.swift
        Sources/Tina/Core/AppearanceStrings.swift
        Sources/Tina/Core/GeneralSettingsStrings.swift
        Sources/Tina/Core/SettingsPageStrings.swift
        Sources/Tina/Core/BatteryTimeStrings.swift
        Sources/Tina/Core/CPUCoreStrings.swift
        Sources/Tina/Core/MonitorLayoutStrings.swift
        Sources/Tina/Core/KeepAwakeStrings.swift
        Sources/Tina/Core/BluetoothSleepStrings.swift
        Sources/Tina/Core/PermissionGuideStrings.swift
        Sources/Tina/Core/FanControlStrings.swift
        Sources/Tina/Core/ConnectedDevicesStrings.swift
        Sources/Tina/Services/FanControl/FanControlSupport.swift
        Sources/Tina/Services/FanControl/FanControlResumeSupport.swift
        Sources/Tina/Services/Snippets/TextSnippetSupport.swift
        Sources/Tina/Services/RadialMenu/RadialMenuSupport.swift
        Sources/Tina/Services/QuickTools/ScratchpadSupport.swift
        Sources/Tina/Services/Launchpad/LaunchpadSupport.swift
        Sources/Tina/Services/QuickTools/ScratchpadStore.swift
        Sources/Tina/Services/KillProcess/KillProcessSupport.swift
        Sources/Tina/Services/Recorder/RecorderSupport.swift
        Sources/Tina/Services/Recorder/RecorderSampleTiming.swift
        Sources/Tina/Services/Recorder/RecorderWriter.swift
        Sources/Tina/Services/Recorder/RecorderCaptureEngine.swift
        Sources/Tina/Core/RecorderExportStrings.swift
        Sources/Tina/Core/RecorderExportFormatStrings.swift
        Sources/Tina/Services/Recorder/RecorderComposer.swift
        Sources/Tina/Services/Recorder/RecorderComposerPlan.swift
        Sources/Tina/Services/Recorder/RecorderCursorSprite.swift
        Sources/Tina/Services/Recorder/RecorderTextRenderer.swift
        Sources/Tina/Services/Recorder/RecorderImageRenderer.swift
        Sources/Tina/Services/Recorder/RecorderExporter.swift
        Sources/Tina/Services/Recorder/RecorderGIFClipboard.swift
        Sources/Tina/Services/Recorder/RecorderGIFWriter.swift
        Sources/Tina/Services/Recorder/RecorderFastGIFWriter.swift
        Sources/Tina/Services/Recorder/RecorderGIFWorkspace.swift
        Sources/Tina/Services/Recorder/RecorderComposition.swift
        Sources/Tina/Services/Recorder/RecordingSharingSupport.swift
        Sources/Tina/Services/PrivateFileStore.swift
        Sources/Tina/Services/Recorder/RecorderTakeStore.swift
        Sources/Tina/Services/Recorder/RecorderPresetImageStore.swift
        Sources/Tina/Services/Recorder/RecorderMotion.swift
        Sources/Tina/Services/Recorder/RecorderPointerTrack.swift
        Sources/Tina/Services/Recorder/RecorderTypingTrack.swift
        Sources/Tina/Services/Recorder/RecorderTimeline.swift
        Sources/Tina/Services/Recorder/RecorderTextOverlay.swift
        Sources/Tina/Services/Recorder/RecorderImageOverlay.swift
        Sources/Tina/Services/Recorder/RecorderBlurRegion.swift
        Sources/Tina/Services/Recorder/RecorderEditDocument.swift
        Sources/Tina/Core/AppInfo.swift
        Sources/Tina/Core/GlobalShortcut.swift
        Sources/Tina/Core/SymbolicHotKeys.swift
        Sources/Tina/Services/SystemShortcutTakeoverSupport.swift
        Sources/Tina/Core/Localization.swift
        Sources/Tina/Core/Localizations/Strings+*.swift
        Sources/Tina/Core/FeatureStrings.swift
        Sources/Tina/Core/KillProcessStrings.swift
        Sources/Tina/Core/PortManagerStrings.swift
        Sources/Tina/Core/HostsProfilesStrings.swift
        Sources/Tina/Core/AutoInputSourceStrings.swift
        Sources/Tina/Core/TOTPAuthenticatorStrings.swift
        Sources/Tina/Services/HostsProfiles/HostsProfilesSupport.swift
        Sources/Tina/Services/TOTPAuthenticator/TOTPSupport.swift
        Sources/Tina/Services/TOTPAuthenticator/TOTPKeychainStore.swift
        Sources/Tina/Services/TOTPAuthenticator/TOTPAuthenticatorService.swift
        Sources/Tina/Services/AutoInputSource/AutoInputSourceSupport.swift
        Sources/Tina/Core/WhatsAppDownloadStrings.swift
        Sources/Tina/Core/WhatsAppOrganizerStrings.swift
        Sources/Tina/Core/ReleaseNotes.swift
        Sources/Tina/Core/ReleaseDigest.swift
        Sources/Tina/Core/ReleaseChangeAliases.swift
        Sources/Tina/Core/WhatsNewStrings.swift
        Sources/Tina/Core/URLCleaning.swift
        Sources/Tina/Services/URLCleanerLinkMetadata.swift
        Sources/Tina/Services/GeneralPasteboardAccess.swift
        Sources/Tina/Services/Clipboard/ClipboardHistoryWrite.swift
        Sources/Tina/Services/Clipboard/ClipboardHistoryDrag.swift
        Sources/Tina/Services/Clipboard/ClipboardHistoryFileAccess.swift
        Sources/Tina/Services/Audio/AirPlayRouteManager.swift
        Sources/Tina/Services/Audio/MixerRoutingSupport.swift
        Sources/Tina/Services/Audio/MusicLaunchSupport.swift
        Sources/Tina/Services/Bluetooth/BluetoothSleepSupport.swift
        Sources/Tina/UI/MenuPanel/MixerPercentNativeTextField.swift
        Sources/Tina/UI/MenuPanel/MixerAppDragSource.swift
        Sources/Tina/Services/Audio/BoostLimiter.swift
        Sources/Tina/Services/Audio/MixerRender.swift
        Sources/Tina/Services/Audio/PreciseVolumeRollerSupport.swift
        Sources/Tina/Services/DockPreview/DockPreviewSupport.swift
        Sources/Tina/Services/DockPreview/DockAutohideHold.swift
        Sources/Tina/Services/SpacesOrder/SpacesOrderHold.swift
        Sources/Tina/Services/Homebrew/HomebrewSupport.swift
        Sources/Tina/Services/Homebrew/HomebrewEnvironment.swift
        Sources/Tina/Services/Homebrew/HomebrewManager.swift
        Sources/Tina/UI/HomebrewOperationStatusView.swift
        Sources/Tina/Services/AppUpdates/AppUpdatesSupport.swift
        Sources/Tina/Services/AppUpdates/AppUpdateFeedSupport.swift
        Sources/Tina/Core/AppUpdateStrings.swift
        Sources/Tina/Core/DiskImageInstallerStrings.swift
        Sources/Tina/Services/DiskImageInstaller/DiskImageInstallerSupport.swift
        Sources/Tina/UI/NonModalAlert.swift
        Sources/Tina/Services/Clipboard/ClipboardHistorySupport.swift
        Sources/Tina/Core/ColorValue.swift
        Sources/Tina/Services/Clipboard/ClipboardAutoClearSupport.swift
        Sources/Tina/Services/AutoQuit/AutoQuitSupport.swift
        Sources/Tina/Core/AutoQuitDockAppsStrings.swift
        Sources/Tina/Services/Shelf/ShelfSupport.swift
        Sources/Tina/Services/Shelf/ShelfFilePromiseTransfer.swift
        Sources/Tina/Core/ShelfPromiseDeliveryStrings.swift
        Sources/Tina/Services/Finder/FinderRenameSupport.swift
        Sources/Tina/Services/Update/UpdateInstallerSupport.swift
        Sources/Tina/Services/Update/UpdateServiceSupport.swift
        Sources/Tina/Services/InstalledApps.swift
        Sources/Tina/Services/LaunchAtLoginSupport.swift
        Sources/Tina/UI/Settings/SettingsSearchSupport.swift
        Sources/Tina/UI/Settings/SettingsSidebarSupport.swift
        Sources/Tina/UI/Settings/FeatureVisibilitySupport.swift
        Sources/Tina/UI/Onboarding/WhatsNewSupport.swift
        Sources/Tina/UI/Settings/SettingsWindow.swift
        Sources/Tina/Core/SettingsNavigationStrings.swift
        Sources/Tina/App/MenuBarSpacingSupport.swift
        Sources/Tina/App/MenuBarAllowanceSupport.swift
        Sources/Tina/App/ReopenRequestSupport.swift
        Sources/Tina/App/StatusItemAnchorSupport.swift
        Sources/Tina/Services/DockClick/DockClickSupport.swift
        Sources/Tina/Services/Finder/CutPasteProgressSupport.swift
        Sources/Tina/Services/Finder/CutPastePrivilegeSupport.swift
        Sources/Tina/Services/Finder/FinderPasteImageSupport.swift
        Sources/Tina/Services/MiddleClick/MiddleClickSupport.swift
        Sources/Tina/Services/MouseNavigation/MouseNavigationSupport.swift
        Sources/Tina/Services/MouseNavigation/MouseNavigationKeys.swift
        Sources/Tina/Services/MouseButtons/MouseButtonShortcutSupport.swift
        Sources/Tina/Services/MouseButtons/MouseSpacesGestureSupport.swift
        Sources/Tina/Services/MouseClickDebounce/MouseClickDebounceSupport.swift
        Sources/Tina/Services/MouseExceptions/MouseAppExceptionSupport.swift
        Sources/Tina/Services/MouseExceptions/MouseAppExceptions.swift
        Sources/Tina/Services/WindowServerSupport.swift
        Sources/Tina/Services/WindowMaximizerSupport.swift
        Sources/Tina/Core/MouseButtonStrings.swift
        Sources/Tina/Core/MouseClickDebounceStrings.swift
        Sources/Tina/Core/MouseExceptionStrings.swift
        Sources/Tina/Core/ClipboardIgnoredAppsStrings.swift
        Sources/Tina/Core/ClipboardRetentionStrings.swift
        Sources/Tina/Core/WindowLayoutIgnoredAppsStrings.swift
        Sources/Tina/Services/WindowLayout/WindowLayoutIgnoredApps.swift
        Sources/Tina/Core/WindowPreviewExclusionStrings.swift
        Sources/Tina/Core/WindowMaximizerExclusionStrings.swift
        Sources/Tina/Core/DiskExclusionStrings.swift
        Sources/Tina/Core/SwitcherAppRulesStrings.swift
        Sources/Tina/Services/QuickTools/QuickToolsSupport.swift
        Sources/Tina/Services/CommandBar/CommandBarSupport.swift
        Sources/Tina/Services/CommandBar/CommandBarPreferences.swift
        Sources/Tina/Services/CommandBar/CommandBarMath.swift
        Sources/Tina/Services/CommandBar/CommandBarUnits.swift
        Sources/Tina/Services/CommandBar/CommandBarColors.swift
        Sources/Tina/Services/CommandBar/CommandBarEmoji.swift
        Sources/Tina/Services/CommandBar/CommandBarLinks.swift
        Sources/Tina/Services/CommandBar/CommandBarDates.swift
        Sources/Tina/Services/CommandBar/CommandBarRowShortcuts.swift
        Sources/Tina/Services/CommandBar/CommandBarSystemSettingsSupport.swift
        Sources/Tina/Services/CommandBar/CommandBarFileSearchSupport.swift
        Sources/Tina/Services/CommandBar/CommandBarQueryMemory.swift
        Sources/Tina/Services/SpotlightNamesSupport.swift
        Sources/Tina/Services/QuickTools/MicMuteSupport.swift
        Sources/Tina/Services/QuickTools/QuickTogglesSupport.swift
        Sources/Tina/Services/QuickTools/ScreenshotCapturePolicy.swift
        Sources/Tina/Services/QuickTools/ScreenshotSupport.swift
        Sources/Tina/Services/QuickTools/ScreenshotCanvasSupport.swift
        Sources/Tina/Services/QuickTools/ScreenshotImageImport.swift
        Sources/Tina/Services/Media/MediaImageProcessing.swift
        Sources/Tina/Services/QuickTools/ScreenshotImageFile.swift
        Sources/Tina/UI/Settings/ScreenCaptureToolPicker.swift
        Sources/Tina/UI/Settings/MonitorToken.swift
        Sources/Tina/Services/QuickTools/ScreenshotRenderer.swift
        Sources/Tina/Services/QuickTools/ScreenshotImageLayerRendering.swift
        Sources/Tina/Services/QuickTools/RecentCaptureStore.swift
        Sources/Tina/Services/QuickTools/ScreenshotSharingSupport.swift
        Sources/Tina/Services/QuickTools/WindowActivationPolicy.swift
        Sources/Tina/Services/KeyboardDebounce/KeyboardDebounceSupport.swift
        Sources/Tina/Services/SuperKey/SuperKeySupport.swift
        Sources/Tina/Services/LayoutFix/LayoutFixSupport.swift
        Sources/Tina/Services/SuperKey/SuperKeyMappingGuard.swift
        Sources/Tina/Core/SuperKeyStrings.swift
        Sources/Tina/Core/LayoutFixStrings.swift
        Sources/Tina/Core/InputSourceSelection.swift
        Sources/Tina/Services/SessionActivity.swift
        Sources/Tina/Services/SessionActivitySupport.swift
        Sources/Tina/Services/EventTimestamp.swift
        Sources/Tina/Services/OwnKeyEvent.swift
        Sources/Tina/Services/ScrollWheelSupport.swift
        Sources/Tina/Services/HorizontalWheelScrolling.swift
        Sources/Tina/Services/SmoothScrollSupport.swift
        Sources/Tina/Services/ScrollPerApp/ScrollPerAppSupport.swift
        Sources/Tina/Services/MouseAcceleration/MouseAccelerationSupport.swift
        Sources/Tina/Services/FocusFollowsMouse/FocusFollowsMouseSupport.swift
        Sources/Tina/Services/AssistiveKeyboard.swift
        Sources/Tina/Services/Switcher/SwitcherModels.swift
        Sources/Tina/Services/Switcher/WindowServerCaptureQueue.swift
        Sources/Tina/Services/Switcher/SwitcherSupport.swift
        Sources/Tina/Services/Switcher/SpaceHopSupport.swift
        Sources/Tina/Services/Switcher/WindowUseOrder.swift
        Sources/Tina/Services/Switcher/WindowEnumeratorAccessibilityPrefetch.swift
        Sources/Tina/Services/Metrics/MetricFormat.swift
        Sources/Tina/Services/Metrics/VMStatisticsDecoder.swift
        Sources/Tina/Services/KeepAwakeAutomationSupport.swift
        Sources/Tina/Services/SudoersSupport.swift
        Sources/Tina/Services/Metrics/BatteryTimeSupport.swift
        Sources/Tina/Services/Metrics/BatteryPowerSupport.swift
        Sources/Tina/Services/BoundedProcessRunner.swift
        Sources/Tina/Services/DetachedProcess.swift
        Sources/Tina/Services/ShellSupport.swift
        Sources/Tina/Services/PortManager/PortManagerSupport.swift
        Sources/Tina/Services/Metrics/NetworkProcessSupport.swift
        Sources/Tina/Services/Metrics/NetworkSampler.swift
        Sources/Tina/Services/Metrics/NetworkAddressService.swift
        Sources/Tina/Services/Metrics/SpeedTest.swift
        Sources/Tina/Services/Metrics/PeripheralBatterySampler.swift
        Sources/Tina/Services/Metrics/PeripheralBatterySupport.swift
        Sources/Tina/Services/Metrics/DiskSupport.swift
        Sources/Tina/Services/Metrics/MonitorSamplingPolicy.swift
        Sources/Tina/Services/Metrics/USBDeviceSampler.swift
        Sources/Tina/Services/Metrics/CPUCoreSampler.swift
        Sources/Tina/Services/Metrics/MaxCapacityProbe.swift
        Sources/Tina/Services/Metrics/TemperatureSensorSelector.swift
        Sources/Tina/Services/Metrics/SustainedAlertGate.swift
        Sources/Tina/Services/WindowLayout/WindowLayoutSupport.swift
        Sources/Tina/Services/WindowLayout/WindowTilingSupport.swift
        Sources/Tina/Core/WindowTilingStrings.swift
        Sources/Tina/Services/WindowLayout/WindowStageManagerSupport.swift
        Sources/Tina/Core/WindowStageManagerStrings.swift
        Sources/Tina/Core/WindowEdgeSnapRestoreStrings.swift
        Sources/Tina/Services/WindowLayout/WindowGestureSupport.swift
        Sources/Tina/Services/WindowLayout/WindowCustomZones.swift
        Sources/Tina/Core/WindowCustomZoneStrings.swift
        Sources/Tina/Core/WindowDirectionalStrings.swift
        Sources/Tina/Core/PointerDisplayStrings.swift
        Sources/Tina/Core/GraphScaleStrings.swift
        Sources/Tina/Core/NotchLowBatteryStrings.swift
        Sources/Tina/Services/CleaningMode/CleaningUnlockCounter.swift
        Sources/Tina/Services/CleaningMode/CleaningMouseReleaseGate.swift
        Sources/Tina/Services/Display/ExtraBrightnessSupport.swift
        Sources/Tina/Services/Display/NightWarmthSupport.swift
        Sources/Tina/Services/ChargeLimit/ChargeLimitSupport.swift
        Sources/Tina/Services/ChargeLimit/ChargeLimitXPC.swift
        Sources/Tina/Services/Display/BrightnessSupport.swift
        Sources/Tina/Services/Display/MonitorVolumeKeySettings.swift
        Sources/Tina/Services/Display/LidDimmingSupport.swift
        Sources/Tina/Services/Cleaner/CleanerSupport.swift
        Sources/Tina/Services/Cleaner/CleanerPolicy.swift
        Sources/Tina/Services/Cleaner/CleanerSchedule.swift
        Sources/Tina/Services/Uninstall/UninstallerSupport.swift
        Sources/Tina/Services/ManagedDownloads/WhatsAppDownloadSupport.swift
        Sources/Tina/Core/SecureInputSupport.swift
        Tests/*.swift
        build/generated-tests/*.swift
    )
    TEST_OUTPUT_FILE_MAP="$TEST_OBJECT_DIR/output-file-map.json"
    write_swift_output_file_map "$TEST_OUTPUT_FILE_MAP" "$TEST_OBJECT_DIR" "${TEST_SOURCES[@]}"
    echo "▸ Building & running tests against $(basename "$SDK")…"
    swiftc -Onone -incremental -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
        -module-name TinaTests -output-file-map "$TEST_OUTPUT_FILE_MAP" \
        -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" \
        "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${CORE_AUDIO_TAP_FLAGS[@]}" "${GIF_CODEC_FLAGS[@]}" \
        "${TEST_SOURCES[@]}" "${GIF_CODEC_OBJECTS[@]}" -o build/metrics-tests
    test_status=0
    ./build/metrics-tests "${TEST_ARGS[@]}" || test_status=$?
    if (( ${#TEST_ARGS} == 0 )); then
        ./Tests/PreferenceCleanupTests.sh || test_status=1
        ./Tests/UninstallSpacesTests.sh || test_status=1
        ./Tests/DeveloperInstallIsolationTests.sh || test_status=1
    fi
    discard_test_preferences || test_status=1
    exit $test_status
fi

echo "▸ Compiling ($BUILD_CONFIGURATION) against $(basename "$SDK")…"
APP_SOURCES=(Sources/Tina/**/*.swift)
if (( ! DEV )); then
    # A release starts from an empty build directory, so nothing an earlier
    # build left behind (an old icon catalog, a staged bundle) can reach it.
    # Only the compiler's incremental records stay: they rebuild whatever
    # changed since, and a fresh checkout has none.
    find build -mindepth 1 -maxdepth 1 ! -name objects -exec rm -rf {} + 2>/dev/null || true
fi
APP_OBJECT_DIR="build/objects/$EXECUTABLE"
mkdir -p build "$APP_OBJECT_DIR"
APP_OUTPUT_FILE_MAP="$APP_OBJECT_DIR/output-file-map.json"
write_swift_output_file_map "$APP_OUTPUT_FILE_MAP" "$APP_OBJECT_DIR" "${APP_SOURCES[@]}"
# Without -j the driver compiles one file at a time, and without batch mode
# each file's compiler parses the whole module again: a clean release took a
# quarter of an hour. Batches share that work and run on every core, and the
# optimization stays per file, as before.
swiftc "${APP_OPTIMIZATION_FLAGS[@]}" -incremental -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
    -output-file-map "$APP_OUTPUT_FILE_MAP" \
    -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${HID_EVENT_SYSTEM_FLAGS[@]}" \
    "${CORE_AUDIO_TAP_FLAGS[@]}" "${GIF_CODEC_FLAGS[@]}" \
    "${BUILD_VARIANT_FLAGS[@]}" \
    "${APP_SOURCES[@]}" "${GIF_CODEC_OBJECTS[@]}" -o "build/$EXECUTABLE"
xcrun dyld_info -imports "build/$EXECUTABLE" | awk -f Tests/AudioTapImports.awk

echo "▸ Compiling protected helper…"
# One privileged daemon serves both Fan Control and the charge limit; each
# capability owns its own controller, marker and teardown inside it.
swiftc -O -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${BUILD_VARIANT_FLAGS[@]}" \
    Sources/Tina/Services/FanControl/FanControlSupport.swift \
    Sources/Tina/Services/FanControl/FanControlXPC.swift \
    Sources/Tina/Services/SystemMonitor/SMCClient.swift \
    Sources/Tina/Services/Metrics/TemperatureSensorSelector.swift \
    Sources/Tina/Services/FanControl/FanControlHardware.swift \
    Sources/Tina/Services/ChargeLimit/ChargeLimitSupport.swift \
    Sources/Tina/Services/ChargeLimit/ChargeLimitXPC.swift \
    Sources/Tina/Services/ChargeLimit/ChargeLimitHardware.swift \
    Sources/FanControlHelper/main.swift \
    -o "build/$FAN_HELPER_ID"
"build/$FAN_HELPER_ID" --selftest

echo "▸ Compiling Now Playing adapter…"
swiftc -O -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" -emit-library \
    -module-name TinaNowPlaying \
    Sources/NowPlayingAdapter/NowPlayingAdapter.swift \
    Sources/NowPlayingAdapter/NowPlayingQueue.swift \
    Sources/NowPlayingAdapter/NowPlayingSelection.swift \
    Sources/Tina/Services/Notch/NotchPlaybackSource.swift \
    Sources/Tina/Services/Notch/NotchPlaybackCommand.swift \
    -o "build/$NOW_PLAYING_ADAPTER"

echo "▸ Generating app icon…"
# The supplied 1024 PNG is authoritative; MakeIcon writes AppIcon.icns and the
# menu bar/BrandMark assets. A stale Assets.car from an older adaptive build
# must not survive, or macOS would prefer it over the new .icns.
rm -f build/Assets.car build/actool-failure.log
swift Tools/MakeIcon.swift build/AppIcon.iconset
xattr -c -r build/AppIcon.iconset build/AppIcon.icns build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png 2>/dev/null || true
ACTOOL_BIN="$(xcrun --find actool 2>/dev/null || true)"
ICON_TMP="$(mktemp -d)"
# The Launchpad Dock icon, copied into the helper app it writes.
rm -f build/LaunchpadIcon.car build/LaunchpadIcon.icns
LAUNCHPAD_ICON_SKIP=""
if [[ -z "$ACTOOL_BIN" ]]; then
    LAUNCHPAD_ICON_SKIP="actool not found (adaptive icons need Xcode 26+)"
else
    echo "▸ Compiling Launchpad icon catalog…"
    # actool crashes on File Provider-synced paths, so compile a local copy.
    mkdir -p "$ICON_TMP/Launchpad/catalog"
    ditto "Resources/Brand/LaunchpadIcon.icon" "$ICON_TMP/Launchpad/AppIcon.icon"
    if "$ACTOOL_BIN" "$ICON_TMP/Launchpad/AppIcon.icon" \
            --compile "$ICON_TMP/Launchpad/catalog" \
            --app-icon AppIcon \
            --platform macosx \
            --target-device mac \
            --minimum-deployment-target 14.0 \
            --enable-on-demand-resources NO \
            --output-partial-info-plist "$ICON_TMP/Launchpad/partial-info.plist" \
            >"$ICON_TMP/Launchpad/actool.log" 2>&1 && [[ -s "$ICON_TMP/Launchpad/catalog/Assets.car" ]]; then
        mv "$ICON_TMP/Launchpad/catalog/Assets.car" build/LaunchpadIcon.car
        mv "$ICON_TMP/Launchpad/catalog/AppIcon.icns" build/LaunchpadIcon.icns
    else
        LAUNCHPAD_ICON_SKIP="actool could not compile the catalog"
        cp "$ICON_TMP/Launchpad/actool.log" build/launchpad-actool-failure.log 2>/dev/null || true
    fi
fi
if [[ -n "$LAUNCHPAD_ICON_SKIP" ]]; then
    echo "  Launchpad icon skipped: $LAUNCHPAD_ICON_SKIP (the Dock icon falls back to a drawn one)"
fi
echo "▸ Assembling and signing bundle…"
STAGE_TMP="$(mktemp -d)"
STAGE="$STAGE_TMP/$APP_NAME.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" \
    "$STAGE/Contents/Library/LaunchDaemons" "$STAGE/Contents/Library/LaunchServices"
cp "build/$EXECUTABLE" "$STAGE/Contents/MacOS/$EXECUTABLE"
cp "build/$FAN_HELPER_ID" "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID"
mkdir -p "$STAGE/Contents/Frameworks"
cp "build/$NOW_PLAYING_ADAPTER" "$STAGE/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
cp Resources/now-playing.pl "$STAGE/Contents/Resources/now-playing.pl"
cp Resources/agent-prices.json "$STAGE/Contents/Resources/agent-prices.json"
cp Resources/com.tina.utils.fan-control.plist \
    "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
cp Resources/Info.plist "$STAGE/Contents/Info.plist"
for lproj in Resources/*.lproj(N); do
    cp -R "$lproj" "$STAGE/Contents/Resources/"
done
if (( DEV )); then
    # A distinct identity so the Developer build installs and runs next to the
    # official app, with its own permissions, preferences and login item.
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE" "$STAGE/Contents/Info.plist"
    # Its own link scheme, so the Launchpad Dock icon a build writes opens that build.
    /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLName $APP_BUNDLE_ID" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 tina-dev" "$STAGE/Contents/Info.plist"
    FAN_PLIST="$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
    /usr/libexec/PlistBuddy -c "Set :Label $FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Set :BundleProgram Contents/Library/LaunchServices/$FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Delete :MachServices:com.tina.utils.fan-control" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Add :MachServices:$FAN_HELPER_ID bool true" "$FAN_PLIST"
    # Stamp the source commit + build time so the running dev app shows (in About)
    # exactly which code it was compiled from. Lets you verify it matches HEAD before
    # testing, instead of unknowingly running a stale build. Dev-only; never shipped.
    SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && SHA="$SHA-dirty"
    /usr/libexec/PlistBuddy -c "Add :TinaBuildCommit string '$SHA · $(date '+%Y-%m-%d %H:%M')'" "$STAGE/Contents/Info.plist"
    echo "  stamped dev build: $SHA"
fi
FAN_HELPER_VERSION="$(
    export LC_ALL=C
    /usr/bin/shasum -a 256 \
        "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID" \
        "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist" \
        | /usr/bin/awk '{print $1}' | /usr/bin/shasum -a 256 \
        | /usr/bin/awk '{print $1}'
)"
/usr/libexec/PlistBuddy -c "Add :TinaFanControlHelperVersion string '$FAN_HELPER_VERSION'" \
    "$STAGE/Contents/Info.plist"
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
cp build/AppIcon.icns "$STAGE/Contents/Resources/AppIcon.icns"
cp Sources/RecorderGIFCodec/vendor/cgif/LICENSE "$STAGE/Contents/Resources/cgif-LICENSE.txt"
cp build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png "$STAGE/Contents/Resources/"
if [[ -f build/Assets.car ]]; then
    cp build/Assets.car "$STAGE/Contents/Resources/Assets.car"
fi
for LAUNCHPAD_ICON in build/LaunchpadIcon.car build/LaunchpadIcon.icns; do
    if [[ -f "$LAUNCHPAD_ICON" ]]; then cp "$LAUNCHPAD_ICON" "$STAGE/Contents/Resources/"; fi
done
if [[ -d Resources/Gifs ]]; then
    mkdir -p "$STAGE/Contents/Resources/Gifs"
    cp Resources/Gifs/*.gif "$STAGE/Contents/Resources/Gifs/"
fi
if ! cmp -s Resources/Gifs/highlights-notch.gif "$STAGE/Contents/Resources/Gifs/highlights-notch.gif"; then
    echo "Dynamic Island tour GIF is missing or differs from the bundled copy" >&2
    exit 1
fi
if [[ -d Resources/Images ]]; then
    mkdir -p "$STAGE/Contents/Resources/Images"
    cp Resources/Images/* "$STAGE/Contents/Resources/Images/"
fi
xattr -c -r "$STAGE" 2>/dev/null || true

# Signing, in order of preference:
#   1. Developer ID Application — the real, Apple-issued identity used for
#      notarized releases. Signed with the hardened runtime (required for
#      notarization), the app's entitlements and a secure timestamp. Gives a
#      stable, team-based designated requirement, so permissions persist across
#      updates AND Gatekeeper shows no "unverified developer" warning.
#   2. "Tina Utils Signing" — the legacy stable self-signed identity, kept
#      as a fallback so contributors without a Developer ID still get a constant
#      designated requirement across their local builds.
#   3. Ad-hoc — fresh clone with no identity at all.
DEVID="$(developer_id_identity)"
codesign_app() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --sign - "$target"
    fi
}

codesign_fan_helper() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --identifier "$FAN_HELPER_ID" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" \
            --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" --sign - "$target"
    fi
}

codesign_now_playing_adapter() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --identifier "$NOW_PLAYING_ADAPTER_ID" \
            --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --identifier "$NOW_PLAYING_ADAPTER_ID" --sign - "$target"
    fi
}

sign_bundle() {
    local bundle="$1"
    local executable="$bundle/Contents/MacOS/$EXECUTABLE"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"

    if [[ -n "$DEVID" ]]; then
        echo "  signing with Developer ID (hardened runtime): $DEVID"
    elif legacy_identity_installed; then
        echo "  signing with legacy self-signed identity: $LEGACY_IDENTITY"
    else
        echo "  signing ad-hoc (no identity installed — run Tools/setup-signing.sh)"
    fi
    [[ -f "$helper" ]] && codesign_fan_helper "$helper"
    [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
    codesign_app "$bundle"

    # If local filesystem metadata invalidates the first signature, sign once
    # more. The installed Developer bundle is signed again after the final copy.
    if ! codesign --verify --deep --strict "$bundle" >/dev/null 2>&1; then
        echo "  re-signing after filesystem metadata settled"
        xattr -c -r "$bundle" 2>/dev/null || true
        [[ -f "$helper" ]] && codesign_fan_helper "$helper"
        [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
        codesign_app "$bundle"
    fi
    [[ -f "$executable" ]] && codesign --verify --strict "$executable"
    [[ -f "$helper" ]] && codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && codesign --verify --strict "$adapter"
    codesign --verify --deep --strict "$bundle"
}

sign_installed_bundle() {
    local bundle="$1"
    wait_for_install_metadata "$bundle"
    sign_bundle "$bundle"
}

sign_bundle "$STAGE"

process_is_running() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pgrep -f "/Contents/MacOS/$proc" >/dev/null 2>&1
    else
        pgrep -x "$proc" >/dev/null 2>&1
    fi
}

stop_process() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pkill -f "/Contents/MacOS/$proc" 2>/dev/null || true
    else
        pkill -x "$proc" 2>/dev/null || true
    fi
    for _ in {1..50}; do
        if ! process_is_running "$proc"; then
            return 0
        fi
        sleep 0.1
    done
    echo "✗ $proc is still running — quit it and retry" >&2
    return 1
}

wait_for_install_metadata() {
    local bundle="$1"
    local missing
    for _ in {1..50}; do
        missing=0
        while IFS= read -r file; do
            if ! xattr -p com.apple.provenance "$file" >/dev/null 2>&1; then
                missing=1
                break
            fi
        done < <(find "$bundle/Contents" -type f ! -path "*/_CodeSignature/*")
        if (( missing == 0 )); then
            return 0
        fi
        sleep 0.1
    done
}

# Installed development builds only need the copy in /Applications. Retaining
# another app in each checkout pollutes application search with stale builds.
if (( DEV )); then
    for old_bundle in "build/stage/$APP_NAME.app" "build/stage.noindex/$APP_NAME.app"; do
        if [[ -d "$old_bundle" ]]; then
            /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
                -u "$PWD/$old_bundle" >/dev/null 2>&1 || true
            rm -rf "$old_bundle"
        fi
    done
fi

if (( !DEV || !INSTALL )); then
    STAGE_DIRECTORY="build/stage"
    (( DEV )) && STAGE_DIRECTORY="build/stage.noindex"
    mkdir -p "$STAGE_DIRECTORY"
    BUILD_STAGE="$STAGE_DIRECTORY/$APP_NAME.app"
    rm -rf "$BUILD_STAGE"
    ditto --noextattr --noqtn "$STAGE" "$BUILD_STAGE"
    xattr -c -r "$BUILD_STAGE" 2>/dev/null || true
    if ! codesign --verify --deep --strict "$BUILD_STAGE" >/dev/null 2>&1; then
        if xattr -lr "$BUILD_STAGE" 2>/dev/null | grep -Eq 'com\.apple\.(FinderInfo|ResourceFork|provenance|fileprovider)'; then
            echo "  staging copy has local filesystem metadata; temp bundle was verified"
        else
            codesign --verify --deep --strict "$BUILD_STAGE"
        fi
    fi
    echo "✓ Bundle ready: $BUILD_STAGE"
fi

if (( INSTALL )); then
    echo "▸ Installing into /Applications…"
    stop_process "$EXECUTABLE"
    # Only an official install replaces the pre-rename official apps. The
    # Developer variant must coexist with them just as it does with Tina.
    if (( ! DEV )); then
        for legacy in "Vorss:Vorss" "Tina Utils:TinaUtils"; do
            name="${legacy%%:*}"; proc="${legacy##*:}"
            if [[ -d "/Applications/$name.app" ]]; then
                stop_process "$proc"
                rm -rf "/Applications/$name.app"
                echo "  (legacy $name.app removed)"
            fi
        done
    fi
    INSTALL_DEST="/Applications/$APP_NAME.app"
    rm -rf "$INSTALL_DEST"
    ditto --noextattr --noqtn "$STAGE" "$INSTALL_DEST"
    sign_installed_bundle "$INSTALL_DEST"
    echo "✓ Installed: $INSTALL_DEST"
fi
