# Relic & Reserve R3 music routing

All imported music for this project is kept under `audio/` and is not shared
with another game:

- `audio/bgm/relic_reserve_bgm/` — instrumental workshop, market, event,
  inspection, auction and Grand Reserve tracks.
- `audio/title/relic_reserve_title/` — title music.
- `audio/endings/relic_reserve_endings/` — ending-specific and postgame music.

The runtime uses one dedicated `BGMManager` stream. A screen transition stops
the previous track before loading the next one, so two project tracks cannot
overlap. Button presses use the separate `audio/ui_click.wav` SFX player.

Ending routing:

| State | Track |
|---|---|
| `ENDING_S` | `01_see_you_tomorrow.mp3` |
| `ENDING_A` | `02_the_memory_we_keep.mp3` |
| `ENDING_B` | `03_after_the_final_bell.mp3` |
| `ENDING_C` | `04_summer_never_ends.mp3` |
| `ENDING_D` | `05_our_next_adventure.mp3` |
| `POSTGAME` | `06_the_sky_is_still_blue.mp3` |
