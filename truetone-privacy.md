# TrueTone Manager — Privacy Policy

_Last updated: 8 July 2026_

TrueTone Manager ("the app") is a free, open-source macOS menu bar utility developed by Martin Rusetski ("the developer", "I", "me"). This is the privacy policy for TrueTone Manager specifically. General terms that apply to all of the developer's apps are in the separate [Terms of Service](https://martinrusetski.com/terms).

## Summary

TrueTone Manager does not collect, transmit, sell, or share any personal data. There are no analytics, no telemetry, no tracking, no advertising, and no user accounts. Everything the app stores stays on your Mac.

## What the app stores, and where

The app saves your per-app True Tone rules, your default state, and your launch-at-login preference to a local file on your Mac:

```
~/Library/Application Support/TrueToneManager/preferences.json
```

This file never leaves your device. It is not uploaded anywhere, and the developer has no access to it.

## What the app reads

To function, the app reads:

- The identity of the app currently in the foreground (via macOS `NSWorkspace`), so it can apply the matching rule.
- Your display's True Tone capability and current state (via macOS system frameworks).

This information is used only in the moment, on your Mac, to decide whether to toggle True Tone. It is not logged, stored beyond your saved rules, or transmitted.

## Network activity

The app has one form of network activity: checking for software updates. When an update check runs, the app contacts GitHub to fetch the update feed and, if you choose to install an update, to download it.

- This connection is made to GitHub's servers. Like any web request, it may expose your IP address to GitHub, whose handling of that data is governed by [GitHub's Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
- The developer does not receive, collect, or store any information from these update checks.
- The app does not send any information about you, your Mac, or your usage to the developer.
- You can turn automatic update checks off in the app's settings. With them off, the app makes no network connections on its own.

## Third parties

Aside from the GitHub connection used for updates described above, the app does not communicate with any third-party service.

## Children's privacy

The app is a general-purpose utility and is not directed at children. It collects no personal data from anyone, including children.

## App-specific notes

- TrueTone Manager toggles True Tone using a private Apple CoreBrightness interface, which is the same system-wide switch as the True Tone checkbox in System Settings. Because it relies on a private interface, the app is not distributed through the Mac App Store and is not notarized by Apple, and macOS may display a warning on first launch.
- Requirements: an Apple Silicon Mac running macOS 13 (Ventura) or later.

## Changes to this policy

If this policy changes, the "Last updated" date above will change and the current version will be published at the app's official page. Continued use of the app after an update constitutes acceptance of the revised policy.

## Contact

- Developer: Martin Rusetski
- Website: https://martinrusetski.com
- Project: https://github.com/martinrusetski/true-tone-manager
- Email: _add your preferred contact email here_
