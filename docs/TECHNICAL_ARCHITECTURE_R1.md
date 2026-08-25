# Technical Architecture R1

`GameState` is an autoload for save/load, seeded RNG, artifact instances, restoration, appraisal, auction, and economy. `main.gd` is the screen router and renderer. JSON data is split by content domain. The loop is deterministic from artifact seed plus day.
