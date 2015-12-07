#!/bin/bash
hdiutil create -size 8m -fs HFS+ -volname "Taskwarrior Pomodoro" taskwarrior-pomodoro.dmg
hdiutil attach taskwarrior-pomodoro.dmg

ln -s /Applications /Volumes/Taskwarrior\ Pomodoro/
cp -rf Taskwarrior\ Pomodoro.app /Volumes/Taskwarrior\ Pomodoro/

hdiutil detach /Volumes/Taskwarrior\ Pomodoro
hdiutil convert taskwarrior-pomodoro.dmg -format UDZO -o taskwarrior-pomodoro-X.X.X.dmg
rm taskwarrior-pomodoro.dmg
