<div align="center">
    <h1>BaseWars</h1>
</div>

<p align="center">
    <img alt="Garry's Mod" src="https://img.shields.io/badge/Garry%27s%20Mod-gamemode-blue">
    <img alt="Version" src="https://img.shields.io/badge/version-1.0.0-green">
    <img alt="License" src="https://img.shields.io/github/license/Brov3r/BaseWars">
</p>

**BaseWars** is a Garry's Mod gamemode: build a base, defend it and raid your opponents.

## 🚀 Quick Start

1. Copy `BaseWars` to `garrysmod/gamemodes/`.
2. Restart the server.
3. Select a `bw_*` map.

## ⚙️ Configuration

All settings are in [`gamemode/config.lua`](./gamemode/config.lua).

| Option | Description |
| --- | --- |
| `Map.RemoveDoors`, `Map.RemoveGlass` | Remove map doors and glass |
| `MapZones.Default` | Damage above and below height limits |
| `Economy.MaxMoney` | Maximum player balance |
| `Ownership.RemoveOnDisconnect` | Remove owned entities on disconnect |
| `CPPI` | Optional prop access layer: friend access and admin tools |
| `Notify` | Notification queue, opacity and sound |
| `Scoreboard`, `WeaponSelector`, `Chat` | Interface and chat settings |

## 📄 Documentation

Configuration is documented with comments inside `gamemode/config.lua`.

## ⚖️ License

This project is licensed under the [MIT License](./LICENSE).
