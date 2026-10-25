# Changelog

## 2.3.0

- Your listing updates by itself when you join a team or your rating changes (no more delist / relist); the ratings are read again after each arena match and every minute while listed.
- The generated group title keeps following your rating; it no longer gets saved as your own text.
- Global ads that spell paladin "paly" are recognised ("Hpaly" is a Holy Paladin healer, also "rpaly", "prot paly" ...).
- Removed the `/rl` reload shortcut: other addons use it too. Use `/reload`.
- About page: the other addons are listed by their readable names, and Skoms Arena Stats is included.

## 2.2.0

- The group title is prefilled from your choices and follows them until you type your own. It is what the Global announcement posts, followed by "(ArenaLFG)".
- *Different message for Global chat* in the listing form lets you write a separate announcement.
- Title and Global message are kept per bracket (2v2, 3v3, DuoQ) and saved as you type.
- An *About* page in the options with help links and the other Skom addons.
- *Copy armory link* in a listing's right-click menu.

## 2.1.0

- The Global announcement now ends with your group title when you set one.

## 2.0.0

- Applicants list shows team rating and gearscore and sorts by name, role, rating or gearscore; *Send application* in a row's right-click menu prefills a whisper with your spec, class, gearscore and experience.
- Remove the `/alfg global` command.
- Tint listings red (declined you), blue (friends) and green (guildmates); add a *Looking for my spec* filter.
- Hide players from the row's right-click menu (`/alfg hide`, `/alfg unhide`, `/alfg hidden`); their listings and sign-ups are ignored.
- Remember the window position.
- Tell you once when another ArenaLFG user runs a newer version.
- Remove your listing while you are AFK and restore it when you are back (not during a battleground or arena).
- Import 3v3 (`3v3`, `3s`, `3c3`...) and duo (`duo`, `duoq`) ads from Global chat into the matching tab.
- Partner match alerts only fire for the bracket you are looking in and name it; DuoQ listings without a Solo Queue team show as Unrated.
- Auto-reply to whispers and party invites while your group is listed and you are in an arena match (SoloQ); option in the options page.
- Add a "Reply to <player>" entry to the Share menu to answer whoever whispered you last about the addon.
- Keep your listing when a SoloQ or battleground match is found, not only once inside the instance.
- 3v3 listings: choose a comp and whether you are alone or with a partner instead of picking one role; announcements and listings show the specs still needed (for example `Awar LF Ele+Hpal 3v3`).
- Your listing is no longer removed when you queue for or enter a battleground or arena (including SoloQ); a 3v3 listing also stays up in a party of two.
- Add 3v3 and DuoQ (Solo Queue) brackets: switch between the 2v2, 3v3 and DuoQ tabs to browse and list groups for each. Your team and rating are read from the matching arena team.
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
