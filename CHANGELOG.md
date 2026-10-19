# Changelog

## Unreleased

- Share ArenaLFG works without a listing: the Share button moved to the bottom of the main window; PvP integration and alert toggles are now only in the options page.
- Join the Global channel automatically at login if you are not already in it (visible, unlike the hidden sync channel).
- Remove the Global channel name setting from the options page.
- Add an options page under Interface > AddOns > ArenaLFG (also `/alfg options` or right-click the minimap button) with all settings, Global announcement on/off and frequency (2-30 minutes), and alert sound choices.
- Add profiles (switch, create, copy, delete, reset) shared across characters; existing settings move to the "Default" profile.
- Use a group-invite chime for sign-ups and a softer, separate sound for partner match alerts; both can be changed in the options.
- Hide the role and spec when they are unknown (for example, on some Global chat ads).
- Show the addon version in the main window, minimap tooltip and options, and with `/alfg version`.

## 1.4.0

- Add opt-in Global announcements for listed groups and a Share button for Global.
- Improve announcement formatting and status, and enlarge the consent popup.
- Improve Global ad parsing for common 2v2 formats and apply browser filters consistently.

## 1.3.0

- Import Global chat 2v2 partner ads as temporary local listings, with best-effort parsing; improve ad recognition and skip identical repeats.
- Add faction indicators and improve Global-ad presentation in the group browser.
- Sort listings by newest post while keeping ArenaLFG listings above imported ads.
- Improve refresh controls and keep the browser scrollbar visible.

## 1.2.0

- Show race icons to help identify players from the opposite faction.
- Redesign the listed-group card to match browser listings and show listing age.
- Expire saved listings after five minutes and retry failed sync-channel joins.
- Defer refresh responses until the broadcast cooldown ends, with a random delay.
- Improve search matching, refresh cooldown feedback, and per-character profile cleanup.

## 1.1.0

- Add role-filtered preferred partner spec selection, including an any-spec option.
- Show specialization icons on group cards and browser listings, and partner preferences in listing titles.
- Add class-colored names, listing age, and application sound alerts while the window is closed.
- Save listing preferences separately for each character.
- Improve role detection, listing and application expiry, and automatic delisting when grouped or in PvP instances.
- Throttle refresh requests and validate invite/decline status messages.
- Integrate ArenaLFG with the PvP frame and clarify GearScore fallback behavior.

## 1.0.1

- Initial public release.
