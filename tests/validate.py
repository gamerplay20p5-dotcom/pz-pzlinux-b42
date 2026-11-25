"""Validate package and local Umbrella declarations; does not run the PZ engine."""
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "Contents/mods/B42 PZLinux"
MEDIA = MOD / "42/media"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--umbrella", type=Path, default=Path(
        r"C:\Users\Malaio\Desktop\Umbrella .21\Umbrella-main\library"))
    args = parser.parse_args()
    assert args.umbrella.is_dir(), "Pass --umbrella with the local library directory"
    luac = shutil.which("luac") or shutil.which("luac5.4")
    lua = shutil.which("lua") or shutil.which("lua5.4")
    assert luac and lua, "Lua 5.4 and luac are required"
    files = list((MEDIA / "lua").rglob("*.lua"))
    for path in files + list((ROOT / "tests").glob("*.lua")):
        subprocess.run([luac, "-p", str(path)], check=True)
    print(f"PASS Lua syntax: {len(files)} production modules", flush=True)
    for path in files:
        for module in re.findall(r'\brequire\s*\(?\s*["\']([^"\']+)', read(path)):
            assert any((base / side / (module + ".lua")).is_file()
                       for base in (MEDIA / "lua", args.umbrella / "lua")
                       for side in ("shared", "server", "client")), (path.name, module)
    print("PASS package and native module dependencies", flush=True)

    contracts = {
        "java/zombie/iso/IsoGridSquare.lua": [
            "function __IsoGridSquare:AddTileObject(obj)",
            "function __IsoGridSquare:transmitRemoveItemFromSquare(obj)",
            "function __IsoGridSquare:haveElectricity()"],
        "java/zombie/iso/IsoObject.lua": ["function __IsoObject:transmitCompleteItemToClients()"],
        "java/zombie/vehicles/BaseVehicle.lua": ["function __BaseVehicle:createVehicleKey()"],
        "java/zombie/characters/Role.lua": ["function __Role:hasAdminPower()"],
        "java/__global.lua": ["function addVehicle(script, x, y, z)",
                              "function createZombie(x, y, z, desc, palette, dir)"],
        "java/zombie/inventory/ItemContainer.lua": ["function __ItemContainer:DoRemoveItem(item)"],
    }
    for relative, signatures in contracts.items():
        reference = read(args.umbrella / relative)
        for signature in signatures:
            assert signature in reference, (relative, signature)
    assert all(":removeTileObject(" not in read(path) for path in files)
    print("PASS critical B42.21 native declarations and world removal API", flush=True)

    config = read(MEDIA / "lua/shared/PZLinuxConfig.lua")
    definitions = {name: default.strip() for name, default in re.findall(
        r"^    (\w+) = \{ default = ([^,}]+)", config, re.M)}
    sandbox = read(MEDIA / "sandbox-options.txt")
    blocks = re.findall(r"option PZLinux\.(\w+)\s*\{([^}]+)\}", sandbox)
    assert len(blocks) == len(definitions) == len({name for name, _ in blocks})
    for name, body in blocks:
        default = re.search(r"default\s*=\s*([^,]+)", body).group(1).strip()
        assert default == definitions[name], (name, default, definitions.get(name))
    for path in files:
        for name in re.findall(r'PZLinuxConfig.Get\("(\w+)"\)', read(path)):
            assert name in definitions, (path.name, name)
    assert "numValues = 2" in sandbox and "valueTranslation = PZLinux_CurrencyMode" in sandbox
    print(f"PASS {len(definitions)} Sandbox options match runtime defaults", flush=True)

    translation = MEDIA / "lua/shared/Translate"
    en_files = {p.name for p in (translation / "EN").glob("*.json")}
    assert en_files == {p.name for p in (translation / "PTBR").glob("*.json")}
    translated = {}
    for filename in sorted(en_files):
        en = json.loads(read(translation / "EN" / filename))
        pt = json.loads(read(translation / "PTBR" / filename))
        assert en.keys() == pt.keys(), f"Translation keys differ in {filename}"
        for key, value in en.items():
            assert isinstance(value, str) and isinstance(pt[key], str), key
            assert "\ufffd" not in value + pt[key], key
            # Check both indexed PZ placeholders and printf-style strings.
            pattern = r"%\d+(?:\$[a-zA-Z])?|%[sdif]"
            assert sorted(re.findall(pattern, value)) == sorted(re.findall(pattern, pt[key])), (filename, key)
        translated.update(en)
    for name in definitions:
        assert "Sandbox_PZLinux_" + name in translated, name
        assert "Sandbox_PZLinux_" + name + "_tooltip" in translated, name
    for number in (1, 2):
        assert "Sandbox_PZLinux_CurrencyMode_option" + str(number) in translated
    for path in files:
        for key in re.findall(r'["\'](UI_PZLinux_[A-Za-z0-9_]+)["\']', read(path)):
            if not key.endswith("_"):
                assert key in translated, (path.name, key)
    for suffix in ("ConvertCopperSilver", "ConvertSilverGold", "RetroGoldSilver", "RetroSilverCopper", "CoinBankLine", "CoinInventoryLine"):
        assert "UI_PZLinux_" + suffix + "_Coins" in translated
    print("PASS EN/PTBR keys, placeholders, currency labels and Sandbox tooltips", flush=True)

    for path in (MOD / "mod.info", MOD / "42/mod.info", MOD / "common/mod.info"):
        text = read(path)
        assert re.search(r"^id=B42_PZLinux42$", text, re.M), path
        assert re.search(r"^versionMin=42\.21$", text, re.M), path
    assert re.search(r"^id=3700371875$", read(ROOT / "workshop.txt"), re.M)
    items = read(MOD / "common/media/scripts/pzlinux-cobre-coin.txt")
    for name in ("CobreCoin", "SilverCoin", "GoldCoin"):
        assert re.search(r"\bitem\s+" + name + r"\b", items)
        assert "Base." + name in translated
    assert (MOD / "common/media/textures/Item_Coin_Copper.png").is_file()
    print("PASS stable mod/workshop IDs and physical currency definitions", flush=True)
    for mode, sides in (("sp", ("shared", "server", "client")),
                        ("server", ("shared", "server")), ("client", ("shared", "client"))):
        modules = [p.relative_to(MEDIA / "lua" / side).with_suffix("").as_posix()
                   for side in sides for p in sorted((MEDIA / "lua" / side).rglob("*.lua"))]
        subprocess.run([lua, str(ROOT / "tests/load_modules.lua"), mode, *modules], check=True)
    subprocess.run([lua, str(ROOT / "tests/regression.lua")], check=True)
    print("Validation passed; real B42.21 SP/hosted/dedicated testing remains pending.")


if __name__ == "__main__":
    main()
