# Changelog

## 1.0.1 — 2026-11-22

### Fishing skill
- The tracker shows your Fishing skill on a skill bar (for example 89 / 150).
- An estimate of your next skill-up, in fishing time and casts, based on how long your recent skill-ups took. It appears after your second skill-up and improves as you fish.
- At your cap, it reminds you to train the next rank.

### Tracker
- Redesigned in the standard WoW window style: title bar, close button, gold labels with white values, and the usual red buttons.
- Session stats in a tidy grid: catches, lifetime, casts, time, value and gold per hour.
- The catch list scrolls with the mouse wheel and shows how many more there are below.
- Times are shorter and easier to read (33m 45s instead of 33 Min 45 Sec), including in `/bb stats`.
- The tracker now opens when you cast, not only when you equip a pole, so it appears even if your pole was already on.

### Lures
- Lures are no longer quietly skipped for the rest of the session. If applying a lure gets interrupted (moving, jumping), the next press just tries again.
- A lure that fails to go on twice in a row is rested for 2 minutes, then tried again, and chat says so.
- Lures are found in every bag, including the extra bag slot.
- A lure with under 10 seconds left is replaced before you cast.
- New `/bb lure` command shows whether your pole has a lure, how long is left, and the status of every lure in your bags.

### Defaults
- New installs and new characters start with every feature off except the minimap button, so Bobber Buddy only does what you turn on.
- Characters that already used 1.0.0 keep their current behaviour, and settings you've chosen are never changed.

## 1.0.0 — 2026-11-21

First release, built for WoW Forever.

### One-key fishing
- One key equips your best pole, puts on fishing gear, uses fishing-buff food or drink, applies your best lure, then casts.
- Press the same key again when the bobber splashes to reel in.
- Fishing gear (hats, boots, gloves, rings, trinkets, cloaks) and buff food are found by reading item tooltips, so new or Forever-only items work too.
- Swap back to your normal gear, weapons included, with a key binding, `/bb gear` or Shift-click on the minimap button.
- Items you can't use yet (level or skill) are skipped, and chat says which one.

### Hearing the bobber
- While fishing: music, ambience and dialog are muted, sound effects turned up, and the game's volume raised by a percentage you choose.
- Optionally mute crafting sounds (anvils, forges), spell sounds, footsteps, and character voices and emotes while you fish. Bobber and fishing sounds are never muted.
- Choose how long after your last cast your sound comes back; it always comes back straight away in combat.

### Tracking
- Session tracker with item icons, tooltips, casts, time spent fishing, session value and gold per hour (Auctionator prices when available, otherwise vendor prices).
- Fishing log: every catch, how many, and which zones, with first and last caught dates, search and sorting, plus time spent fishing by zone.
- Only loot from your own fishing counts. Bought, mailed and quest items never do.
- The tracker can open when you equip a fishing pole and close when you put it away.

### Settings
- Options page under AddOns, with a scrollable layout.
- Set both key bindings right in the options; they also have their own Bobber Buddy section in Key Bindings.
- Typeable boxes next to the sliders.
- Minimap button: left-click tracker, right-click settings, Ctrl-click log, Shift-click swap gear.
