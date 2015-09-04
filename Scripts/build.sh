#!/bin/bash

export PATH=$PATH:/usr/local/bin

xcodebuild -version | grep "Xcode 6" > /dev/null || { echo 'Not running Xcode 6' ; exit 1; }

cd `git rev-parse --show-toplevel`

# Note we don't build iOS on device due to code signing requirements.
xctool -project SwiftRTP.xcodeproj -scheme "SwiftRTP_iOS" -sdk iphonesimulator build test || exit $!
xctool -project SwiftRTP.xcodeproj -scheme "SwiftRTP_OSX" -sdk macosx build test || exit $!
