# ArenaLFG

**An arena partner finder for WoW 3.3.5a (WotLK).** Stop scrolling through global chat: see who is looking for a 2v2, 3v3 or DuoQ partner, sign up with one click, or list your own group, in a window modeled on the Premade Groups finder from modern WoW.

> Built for Warmane (Blackrock) but should work on any 3.3.5a server that allows custom chat channels.

![ArenaLFG window](docs/screenshot.png)

## Features

- **Brackets:** tabs for 2v2, 3v3 and DuoQ (Solo Queue). Your team and rating are read from the matching arena team. In 3v3, pick a comp (for example Thunder Cleave) and whether you are alone or already have a partner; the specs still needed are filled in for you.
- **Group browser** with faction and race icons, class-colored player names, specialization icons, listing age, search and filters for role, team / no team, seasonal / non-seasonal, and "10 games only". ArenaLFG listings appear before Global chat ads; within each group, the most recently posted listings appear first.
- **Chat ad import:** clear 2v2, 3v3 and duo partner ads can appear as temporary listings. Parsed details may be incomplete or inaccurate. The selected-ad button opens a whisper; use the row's right-click menu to invite.
- **Optional Global announcement:** opt in to share your listed group in Global. Posts are public and subject to server chat rules; toggle announcements and set how often they post (every 2 to 30 minutes) in the options, or use `/alfg announce on` / `/alfg announce off`.
- **At a glance:** rows are tinted red (declined you), blue (friends) or green (guildmates), and listings looking for your spec say "Wants you" (filter: *Looking for my spec*). Hide players from the right-click menu (`/alfg hidden`, `/alfg unhide <name>`). The window remembers its position, and you are told once when another ArenaLFG user runs a newer version.
- **AFK:** your listing is removed while you are AFK and restored when you are back.
- **Auto-reply:** while your group is listed and you are in an arena match (SoloQ), whispers and party invites get a short "busy" answer once. Can be turned off in the options.
- **Share ArenaLFG:** prefill a Global chat invitation from the Share button, then review and send it yourself.
- **Sign Up flow** like retail: pick a group, press *Sign Up*, the leader sees you in their applicants list and can *Invite* or decline.
- **Alerts:** sign-ups and invites are announced on screen and in chat with a sound, and partner match alerts (a group or Global ad looking for your spec) use a softer sound. Both sounds can be changed in the options.
- **Options and profiles:** all settings are in *Interface > AddOns > ArenaLFG* (or `/alfg options`, or right-click the minimap button), including the Global announcement frequency. Settings live in profiles you can switch, create, copy, delete and reset; characters share the "Default" profile unless you pick another one.
- **List your group** with role, gearscore, experience tier, preferred partner specs, a short title and flags (seasonal character, 10 games for arena points). The listed-group card mirrors the browser listing and shows your race, class-colored name, role, title, team details and listing age. Settings are saved separately for each character.
- **Preferred partner specs:** choose a role, then select one or more specs or choose **Any spec** (for example, Healer → Holy Paladin and Restoration Druid, or any Healer); their icons or role preference appear in the displayed group title.
- **Auto-detection**: your class, race, spec, 2v2 team and team rating are read from the game. When a GearScore addon exposes `GearScore_GetScore`, ArenaLFG reads your gearscore through that API; otherwise, the gearscore you enter is self-reported.
- **Roles:** DPS, Healer, Tank. Your role is automatically detected from your class and primary talent tree and shown in your listing.
- **PvP UI integration:** enabled by default; ArenaLFG opens beside the PvP window when you open it (H is the default WoW PvP keybinding). Use the options page or `/alfg pvp` to toggle the integration. The minimap button and `/alfg` always open ArenaLFG manually.
- **Topmost window:** ArenaLFG uses the `DIALOG` frame strata and raises itself when opened to stay above most game windows.
- **Clean chat:** ArenaLFG sync traffic is filtered from your regular chat windows.

## Installation

1. Download `ArenaLFG-v2.0.0.zip` from the [Releases page](../../releases) (do **not** use "Download ZIP" on the repository page, it creates a wrongly named folder).
2. Extract it into your addons folder so the path looks like:
   ```
   World of Warcraft\Interface\AddOns\ArenaLFG\ArenaLFG.toc
   ```
3. Start the game and make sure **ArenaLFG** is ticked in the *AddOns* list at character select.

The folder must be named exactly `ArenaLFG`.

## Usage

| Action | How |
| --- | --- |
| Open / close the window | Click the minimap button or type `/alfg` to toggle; open the PvP window (H by default) to open ArenaLFG beside it |
| List your group | Left panel, fill the form, press **List Group** |
| Edit or remove your group | **Edit** / **Delist My Group** (also in the right-click menu on your row) |
| Sign up to a group | Click a group in the list, then **Sign Up** |
| Cancel a sign-up | Select the group, press **Cancel Sign-Up** |
| Invite an applicant | Press **Invite** next to their name (sends a normal party invite) |
| Refresh the list | The refresh button asks other players to announce their groups again; if it is still on cooldown, the remaining wait is shown in chat |
| Share ArenaLFG | Click **Share** in your listed-group view, then review and send the prefilled Global message |

Listings and applications expire automatically when they are no longer current. Your listing can restore after a quick reload, and is removed when a group forms. It stays up while you queue or play battlegrounds and SoloQ. In 3v3, a party of two can keep a listing up to find the last player.

### Notes on your profile

When you sign up to someone's group, the leader receives your role, spec, gearscore, team rating and experience tier. These come from the same form you use to list your own group, so fill it in once.

### Slash commands

| Command | Description |
| --- | --- |
| `/alfg` or `/arenalfg` | Toggle the window |
| `/alfg help` | Show available commands and what they do |
| `/alfg options` | Open the options page |
| `/alfg version` | Show the installed ArenaLFG version |
| `/alfg minimap` | Show or hide the minimap button |
| `/alfg pvp` | Toggle PvP window integration (enabled by default; also controlled in the options page) |
| `/alfg me` | Print what the addon detects about your character (class, spec, GS, arena teams) |
| `/alfg comm` | Check ArenaLFG connection status and retry if needed |
| `/alfg clear` | Clear the local list |
| `/alfg announce on` / `off` | Enable or disable Global announcements for your listed group |
| `/alfg announce prompt` | Reopen the announcement consent prompt |

## How it works

ArenaLFG shares listings with other addon users on your faction. It can also display relevant Global chat ads locally and send sign-ups privately to group leaders. If enabled, your group announcement is posted publicly in Global under your character name; server chat rules apply.

### Privacy

When you list a group, your **character name, class, spec, role, gearscore, 2v2 team rating (if you have a team), experience tier, flags and title** are visible to other ArenaLFG users. When you sign up to a group, the same profile is sent privately to that leader. Global chat ads are parsed locally and are not rebroadcast by ArenaLFG. Nothing is sent outside the game and there is no external server.

## Requirements

- WoW client **3.3.5a** (interface 30300).
- Optional: a compatible GearScore addon (GearScore / GearScoreLite). Without one, or if its score API is unavailable, enter your gearscore by hand; other players cannot verify that value.

## Troubleshooting

- **ArenaLFG listings are not appearing:** make sure other players are using the addon too, then run `/alfg comm` to check or retry the connection.
- **The list stays empty:** the addon is only useful when other players run it too. Ask a friend to install it, post a group, and press the refresh button.
- **A Global chat ad did not appear:** only clear 2v2 partner-seeking messages are imported, and some wording may not be recognized.
- **Your 2v2 team is not detected:** run `/alfg me` and check the arena slots it prints. Open the PvP / arena team frame once, then `/reload`.
- **The addon does not appear in the AddOns list:** check that the folder is named `ArenaLFG` and contains `ArenaLFG.toc` directly (not another folder inside).
- **Lua errors:** enable error display with `/console scriptErrors 1` and open an issue with the message.

## Known limitations

- Visible listings depend on how many players run the addon.
- Global chat parsing recognizes common English wording and can misread ads; inferred details are not verified.
- Gearscore is self-reported (or read from your GearScore addon), so it can be edited by the player.
- Solo-queue style teams reported by the server are ignored; only real 2v2 teams count.

## Contributing / bug reports

Issues and pull requests are welcome. When reporting a bug, include your addon version, the output of `/alfg me`, and any Lua error text.

## License

[MIT](LICENSE)
