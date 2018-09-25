appName='Taskwarrior Pomodoro'
archivesFolder='~/Library/Developer/Xcode/Archives'
todayArchives="$archivesFolder/$(date +%Y-%m-%d)"
appArchivePath="$todayArchives/$appName $(date +%Y-%m-%d,\ %H.%M).xcarchive"
packageName="taskwarrior-pomodoro"
tempPackagePath="builds/distribute/$packageName.dmg"
version=$(defaults read "$PWD/Taskwarrior Pomodoro/Info.plist" CFBundleShortVersionString)

xcodebuild -scheme "$appName" -archivePath "$appArchivePath" archive
xcrun xcodebuild -exportArchive -exportOptionsPlist exportOptions.plist -archivePath "$appArchivePath" -exportPath "builds/distribute"

spctl -a -v "builds/distribute/$appName.app"
echo ""

hdiutil create -size 14m -fs HFS+ -volname "$appName" $tempPackagePath
hdiutil attach $tempPackagePath

ln -s /Applications "/Volumes/$appName/"
cp -rf "builds/distribute/$appName.app" "/Volumes/$appName/"

hdiutil detach "/Volumes/$appName"
hdiutil convert $tempPackagePath -format UDZO -o "builds/distribute/$packageName-$version.dmg"

rm $tempPackagePath
