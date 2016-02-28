version=$(defaults read "$PWD/Taskwarrior Pomodoro/Info.plist" CFBundleShortVersionString)
xcodebuild -scheme "Taskwarrior Pomodoro" -archivePath "builds/Taskwarrior Pomodoro.xcarchive" archive
xcrun xcodebuild -exportArchive -exportOptionsPlist exportOptions.plist -archivePath "builds/Taskwarrior Pomodoro.xcarchive" -exportPath "builds/"

hdiutil create -size 8m -fs HFS+ -volname "Taskwarrior Pomodoro" taskwarrior-pomodoro.dmg
hdiutil attach taskwarrior-pomodoro.dmg

ln -s /Applications /Volumes/Taskwarrior\ Pomodoro/
cp -rf builds/Taskwarrior\ Pomodoro.app /Volumes/Taskwarrior\ Pomodoro/

hdiutil detach /Volumes/Taskwarrior\ Pomodoro
hdiutil convert taskwarrior-pomodoro.dmg -format UDZO -o taskwarrior-pomodoro-$version.dmg
rm taskwarrior-pomodoro.dmg
