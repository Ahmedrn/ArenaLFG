# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ArenaLFG: a 2v2 arena partner finder addon for **WoW 3.3.5a (Interface 30300, Lua 5.1)**, built for Warmane. Pure Lua + `.toc`, no XML, no build step, no linter, no automated tests. The repo folder lives directly in the game's `Interface\AddOns\` directory, so edits are live: **test in game with `/reload`** (enable errors with `/console scriptErrors 1`). Only 3.3.5 APIs exist: no `C_*` namespaces, no `C_Timer`, no modern `Mixin`/`BackdropTemplate`, no addon messages for custom channels.

Branches: `master` (releases), `develop`, `visual-overhaul` (current; UI overhaul, sounds, options/profiles), `claude/upbeat-wright-lyc21h`.

## Token-efficient navigation

Files are large (UI.lua 1390 lines, GlobalParser.lua 591). **Grep for the function, then Read with `offset`/`limit`**; never read whole files. Function index (line numbers drift, grep by name):

| File | Role | Entry points |
| --- | --- | --- |
| `Core.lua` (504) | namespace `ns`, timers, SavedVariables/profiles, sounds, slash commands, group/instance state | `ns.After/Every`, `ns.SetProfile/CopyProfile/DeleteProfile/ResetProfile`, `ns.PlayAlert`, `ns.InGroup`, `ns.InPvpInstance`; slash handler near `SLASH_ARENALFG1` |
| `Data.lua` (256) | race/faction/spec tables, detecting the player's class/spec/role/GS/2v2 team | `ns.GetMySpec*`, `ns.GetMyGearScore`, `ns.GetMy2v2Team`, `ns.DetectMine`, `ns.PARTNER_SPECS` |
| `Listings.lua` (308) | listing model, wire encode/decode, sorting, sign-up flow | `ns.Encode/Decode`, `ns.AddListing/RemoveListing`, `ns.GetSorted`, `ns.MyListing/BuildMine`, `ns.Apply/CancelApply/AddApplicant/InviteApplicant`, `ns.CheckPartnerMatch` |
| `Comm.lua` (369) | hidden-channel sync, Global announcements, refresh cooldown | `ns.Comm_Join`, `ns.Broadcast/BroadcastRemove`, `ns.Comm_Request`, `ns.TryAnnounceMine`, `ns.SetAnnounceEnabled` |
| `GlobalParser.lua` (591) | heuristic parser turning Global chat ads into temporary listings | `ns.ParseGlobalListing` (alias tables at top: classes, specs, races, intent/queue markers) |
| `UI.lua` (1390) | main window: browser list, rows, filters, listed-group view, form view, PvP-frame integration | `ns.BuildUI`, `RefreshList`, `BuildRow`, `BuildGroupView`, `BuildFormView`, `ns.RefreshAll`, `ns.ToggleUI`, `ns.ShowUIAtPVP` |
| `Options.lua` (386) | Interface > AddOns panel and profile panel | `ns.BuildOptions/OpenOptions/RefreshOptions` |
| `Minimap.lua` (74) | minimap button | `ns.BuildMinimapButton` |

## Architecture

- **Load order** is defined in `ArenaLFG.toc`: Core, Data, Listings, GlobalParser, Comm, Minimap, UI, Options. Every file starts with `local ADDON, ns = ...`; all cross-file sharing goes through the `ns` table (also exposed as global `ArenaLFG`, useful for `/run`). Files can only call `ns.*` functions defined in an earlier file at load time; later ones are fine at runtime.
- **State on `ns`**: `ns.listings[name]` (all known listings, including Global-chat imports), `ns.applied[leader]` (my sign-ups: pending/invited/declined), `ns.applicants[name]` (people who applied to me). `ns.Changed()` signals the UI to refresh (UI avoids rebuilds while hidden).
- **Sync transport**: 3.3.5 has no custom-channel addon messages, so listings travel as plain text in a hidden custom channel `ArenaLFGSync` (`ns.CHANNEL`), filtered out of chat frames by `ChatFilter` in Comm.lua. Wire format is semicolon-separated: `AL1;class;spec;role;gs;hasTeam;teamRating;tier;seasonal;tenGames;note;targetRole;targetSpecs;specId;race`; `ALrm` = listing removed; `ALreq` = please re-announce. Decode validates and clamps every field (junk rejection, URL stripping via `NoUrl`); **when adding a field, append it at the end of `Encode` and bump handling in `Decode`** to stay compatible with older clients. Sign-ups use `SendAddonMessage(ns.PREFIX="ARENALFG", ..., "WHISPER", name)` with payloads `AP;<Encode(mine)>` (apply), `CANCEL`, `DEC` (decline), received via `CHAT_MSG_ADDON` in Comm.lua.
- **Timing**: listings expire after `ns.EXPIRE` (150s) without a heartbeat; own listing re-broadcast every `ns.HEARTBEAT` (60s); saved listing survives reload for `ns.LISTING_RESUME_WINDOW` (300s). Timers use the custom `ns.After/ns.Every` (one OnUpdate frame in Core.lua).
- **Global ads**: `GlobalParser.lua` listens to `CHAT_MSG_CHANNEL` on the Global channel, parses class/spec/race/rating/GS/intent, and inserts temporary listings with `l.source == "global"` (expire after 120s, vs `ns.EXPIRE` for ArenaLFG listings; identical repeats are skipped via `chatText`). Best-effort heuristics; ordering puts ArenaLFG listings before Global ads.
- **Optional Global announcements** are opt-in (consent prompt, interval 2-30 min) and posted via `SendChatMessage` to the Global channel in Comm.lua.
- **SavedVariables** `ArenaLFGDB`: account-wide `ns.SV` (`characters[charKey]` = per-character "mine" listing form, `profiles`, `profileKeys`) and the active profile `ns.DB` (alerts, announce, filters, minimap, pvpIntegration). Defaults live in `defaults`, `profileDefaults`, `mineDefaults` in Core.lua; legacy flat settings are migrated into the "Default" profile by `MigrateLegacySettings`.
- **UI** is built entirely in Lua with unnamed-friendly helpers (`MakePanel`, `MakeButton`, `MakeCheck`, `MakeMenuButton`, `NextName`); Options.lua has its own parallel helpers (`Header`, `Label`, `Check`, `Dropdown`). Window uses `DIALOG` strata and hooks the PvP frame to open beside it.

## Dev workflow

- Slash commands for debugging: `/alfg me` (detected class/spec/GS/arena teams), `/alfg comm` (channel status/retry), `/alfg clear`, `/alfg version`, `/alfg help`; `ns.Debug` prints when `debug` is on. Core.lua also defines `/rl` as a reload shortcut.
- Optional integration: GearScore/GearScoreLite via `GearScore_GetScore` (declared in `OptionalDeps`).

- No Lua compiler is installed: syntax-check with `python -m pip install luaparser` then `luaparser.ast.parse(open(f).read())` per file; `lupa` can run `GlobalParser.lua` offline with WoW API stubs (see the parser test pattern: stub `CreateFrame`, `strtrim`, `strsub`, `ns.AddListing`, load `Data.lua` then `GlobalParser.lua`).

## Releasing

- Version lives in `ArenaLFG.toc` (`## Version` and the `X-GitHub-Project-Download` URL) and `README.md` install line (`ArenaLFG-vX.Y.Z.zip`); add notes under `## Unreleased` in `CHANGELOG.md` and move them under the new version heading on release.
- Release zips (`ArenaLFG-v*.zip`) and `ArenaLFG.warperia` are gitignored; the zip must contain a top-level `ArenaLFG/` folder with the `.toc` directly inside. Leave `docs/` (screenshots) and `CLAUDE.md` out of the zip: they are not needed in game. Don't read or glob the zips (large binaries).
- Commit style: short imperative subject lines (e.g. "Add options page with profiles, alert sound choices and version display").

## Project rules

- **README.md** is copy-pasted into the Warperia app on every release so users can update easily: keep it current but concise (no exhaustive detail). Update it whenever user-facing behavior changes.
- **Commits:** always author as `Ahmed Snoussi <ahmed_sn@icloud.com>` (already the repo's git config); commit and push when asked.
