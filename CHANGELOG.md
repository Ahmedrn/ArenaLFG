# Changelog

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
