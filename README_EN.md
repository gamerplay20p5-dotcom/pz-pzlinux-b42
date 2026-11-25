# PZLinux 0.3.0 — Build 42.21

Updated against the local Umbrella B42.21 declarations, with **55 Sandbox settings** and selectable physical currency.

Mod ID remains `B42_PZLinux42`; Workshop ID remains `3700371875`. Install matching client/server versions, keep the `common` and `42` directories and restart. Back up the save first.

## Currency and settings

`PZLinux.CurrencyMode=1` retains vanilla cash: `Base.Money` = 1, `Base.MoneyBundle` = 100. Mode 2 uses `Base.CobreCoin` = 1, `Base.SilverCoin` = 100, `Base.GoldCoin` = 10000. Silver and gold definitions have been restored using the existing coin asset.

`AcceptAlternateCurrency=true` accepts both families for deposits/payments. Disable it to accept only the selected family. Withdrawals, change and currency stacks use the selected family. Changing this setting never multiplies bank balances, changes prices, deletes inventory items or automatically converts them. The numeric bank balance remains the source of truth; denomination counts are a derived representation.

Settings cover module switches, starting balances, cash caps, prices, rewards, betting, demand, stock volatility, catalogs, eligible delivery theft, electricity, extra fuel, wear, repairs, XP, connection caching, mail timing and corpse card drops. Existing defaults are retained; the new cash cap defaults to 100000 base units per operation. The [complete settings table](SANDBOX_PTBR.md) and [detailed audit](README_PTBR.md) are in Portuguese; all in-game labels/tooltips are available in English.

Existing balances, listings, portfolios and paid deliveries are retained. Starting balance settings only apply to accounts with no saved balance. Accepted contracts and already scheduled mail retain their stored rewards/deadlines. Catalog changes apply at renewal. Paid delivery collection and saved-listing cancellation remain available on the server after disabling new purchases/listings.

## Compatibility work

The update corrects cargo removal/replication, preserves pending state on failed/unloaded spawns, waits for server state before advancing multiplayer world requests, validates saved target coordinates and uses native vehicle keys. Cash operations restore inputs on partial failures; repairs require successful scrap removal. Power, fuel and role checks were reviewed, and missing EN/PTBR strings were added.

Vehicle sales retain the existing **JeevesClaims** dependency. Multi Funcoes does not automatically supply that API. Item trading is independent. Legacy bank synchronization still serves parts of contracts, betting, requests and hacking; the entire economy has not been converted to exclusive server authority. Catalog map coordinates were retained and need checking on the actual server map.

## Validation

With Python 3, Lua 5.4 and `luac` on PATH, run from the Workshop directory:

```powershell
python "B42 PZLinux/tests/validate.py"
```

Override the reference with `--umbrella "C:\path\Umbrella-main\library"` if necessary. On 2026-11-04, syntax/dependencies for 52 modules, simulated SP/client/server initialization, 55 setting definitions, EN/PTBR placeholders, currency scripts, critical native declarations and **48 regression tests** passed.

These tests simulate native boundaries. The installed game reports **42.20.2**; actual B42.21 SP, hosted and dedicated playtests remain pending. Test old saves, both currency modes, each module switch, deliveries, two-player transactions, all world contract spawns, generators and optional vehicle claims before publishing.

[Release notes](Contents/mods/B42%20PZLinux/UPDATE_NOTES_EN.txt) · [Workshop description](Contents/mods/B42%20PZLinux/WorkshopDescription_EN.txt)

Pre-update archive: `C:\Users\Malaio\AppData\Local\Temp\PZLinux-before-B42_21-20261104-022247.zip`. Nothing has been uploaded to Steam. Original author credits to Raixxar are retained.
