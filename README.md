# Bobber Buddy

A World of Warcraft fishing addon. One key does the busywork: it equips your pole and fishing gear, uses fishing-buff food, applies your best lure, casts, and reels in when the bobber splashes. It also makes the splash easier to hear and logs everything you catch.

Built for **WoW Forever**, and it also works on Retail.

## Features

- **One-key fishing**: each press does the next thing needed: pole and fishing gear, buff food, lure, cast. Press again when the bobber splashes to reel in.
- **Fishing gear and food** are recognised from item tooltips, so new or Forever-only items just work. Swap back to your normal gear (weapons included) with one key.
- **Hear the bobber**: while fishing, music, ambience and dialog are muted, sound effects turned up and the volume raised by your chosen amount. Optionally mute crafting sounds, spell sounds, footsteps and voices too. Bobber sounds are never muted.
- **Session tracker**: what you've caught this session with icons and tooltips, casts, time, session value and gold per hour. Uses [Auctionator](https://www.curseforge.com/wow/addons/auctionator) prices when installed, otherwise vendor prices.
- **Fishing log**: every catch you've ever made, how many and where, with search, sorting and time spent fishing by zone. Only your own fishing loot counts, never bought or mailed items.
- **Minimap button**, an options page, and its own section in Key Bindings.

## Installation

1. Download the latest release.
2. Extract the `BobberBuddy` folder into:
   - WoW Forever: `World of Warcraft\_forever_\Interface\AddOns\`
   - Retail: `World of Warcraft\_retail_\Interface\AddOns\`
3. Make sure the folder is named `BobberBuddy`, then restart the game.

## Usage

Open **Options > AddOns > Bobber Buddy**, set your fishing key, and tick the features you want. Everything except the minimap button starts **off**, so nothing changes until you choose it: lures, fishing gear, buff food, one-key reel in, the bobber sound options and the tracker.

Then stand by water and press your key. Each press does the next thing you've turned on (gear, food, lure), then casts; with one-key reel in on, press it again when the bobber splashes.

### Slash commands

| Command | What it does |
|---|---|
| `/bb` | Show help |
| `/bb config` | Open the options |
| `/bb log` | Open your fishing log |
| `/bb lure` | Show your lure status (handy if lures aren't going on) |
| `/bb gear` | Swap back to your normal gear |
| `/bb toggle` | Show or hide the session tracker |
| `/bb stats` | Print your fishing statistics |
| `/bb minimap` | Show or hide the minimap button |
| `/bb reset` | Reset the tracker's position |
| `/bb clear` | Clear this session's catches |
| `/bb clearall` | Reset all data (asks first) |

## Building a release

Update `## Version:` in `BobberBuddy.toc`, add a matching `## <version>` section at the top of `CHANGELOG.md`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

This creates `releases\BobberBuddy-<version>.zip`, ready to upload to CurseForge, and copies that version's changelog to the clipboard for the upload form.

`SoundLists.lua` is generated from the [wowdev/wow-listfile](https://github.com/wowdev/wow-listfile) community listfile.

## Reporting bugs

Please open an issue with any Lua error text and what you were doing.

## License

[MIT](LICENSE)
