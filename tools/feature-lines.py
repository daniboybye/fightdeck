#!/usr/bin/env python3
"""The same features, counted twice: what `00-native` writes across both platforms against
what `04-sdk-skip` writes once in its shared SDKs.

    python3 tools/feature-lines.py

count-significant-lines.py says how much each approach carries; this says *where* Skip's
saving comes from and where it does not, by lining up like with like. Lines are counted
exactly as that script counts them, with its own `significant_lines`.

Every Swift file in Skip's shared SDKs must land in a group — a new file that nobody
assigned would otherwise vanish from the comparison, so the script refuses to print instead.
Where the native side keeps a component inside a larger file (`CommonUi.kt`,
`SharedViews.swift`), only that declaration is counted, located by name.
"""

from __future__ import annotations

import importlib.util
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("csl", ROOT / "tools" / "count-significant-lines.py")
_csl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_csl)

N_IOS = "00-native/ios/FightDeck"
N_AND = "00-native/android/app/src/main/java/com/fightdeck/baseline"
S_SDK = "04-sdk-skip/sdks"
S_CORE = f"{S_SDK}/core/Sources/FightDeckCore"


def whole(path: str) -> int:
    return _csl.significant_lines(pathlib.Path(path))


def declaration(path: str, name: str) -> int:
    """Significant lines of one top-level declaration, brace-balanced, with its attributes."""
    lines = (ROOT / path).read_text().splitlines()
    start = next(i for i, l in enumerate(lines)
                 if re.match(rf"^(internal |private |public )?(final )?(fun|struct|func|class|actor|object|enum) {re.escape(name)}\b", l))
    while start > 0 and re.match(r"^\s*@", lines[start - 1]):
        start -= 1
    depth, seen, end = 0, False, start
    for end in range(start, len(lines)):
        depth += lines[end].count("{") - lines[end].count("}")
        seen = seen or "{" in lines[end]
        if seen and depth <= 0:
            break
    probe = ROOT / ".feature-lines-probe.swift"
    probe.write_text("\n".join(lines[start:end + 1]))
    try:
        return _csl.significant_lines(probe.relative_to(ROOT))
    finally:
        probe.unlink()


# (label, [native sources], [skip sources]); a source is a path or (path, declaration name).
GROUPS = [
    ("Betting core", [
        f"{N_IOS}/Core/FightCore.swift", f"{N_IOS}/Core/FightCoreTypes.swift",
        f"{N_IOS}/Core/Money.swift", f"{N_IOS}/Core/OddsEngine.swift",
        f"{N_IOS}/Core/FightCoreDisplay.swift", f"{N_IOS}/Core/DisplayFormatting.swift",
        f"{N_AND}/core/FightCore.kt", f"{N_AND}/core/FightCoreTypes.kt",
        f"{N_AND}/core/Money.kt", f"{N_AND}/core/OddsEngine.kt",
    ], [
        f"{S_CORE}/FightCore.swift", f"{S_CORE}/FightCoreTypes.swift", f"{S_CORE}/Money.swift",
        f"{S_CORE}/OddsEngine.swift", f"{S_CORE}/FightCoreDisplay.swift",
    ]),
    ("Dataset and models", [
        f"{N_IOS}/Data/DatasetModels.swift", f"{N_IOS}/Data/FightRepository.swift",
        f"{N_IOS}/Data/JSONFileRepository.swift", f"{N_AND}/data/Models.kt",
    ], [
        f"{S_CORE}/Ports.swift", f"{S_SDK}/events/Sources/FightDeckEvents/Catalog.swift",
        f"{S_SDK}/events/Sources/FightDeckEvents/Display.swift",
    ]),
    ("Bet slip screen", [
        f"{N_IOS}/Features/Slip/SlipViews.swift", f"{N_AND}/ui/BetSlipScreen.kt",
    ], [
        f"{S_SDK}/betslip/Sources/FightDeckBetslip/BetSlipRootView.swift",
        f"{S_CORE}/BetSlipStore.swift",
    ]),
    ("Deposit screen", [
        f"{N_IOS}/Deposit/DepositFlowView.swift", f"{N_IOS}/Deposit/DepositSheetView.swift",
        f"{N_IOS}/Deposit/DepositContract.swift", f"{N_AND}/ui/DepositScreen.kt",
    ], [
        f"{S_SDK}/deposit/Sources/FightDeckDeposit/DepositFlowView.swift",
    ]),
    ("Fighter screen", [
        f"{N_IOS}/Features/Fighter/FighterProfileView.swift", f"{N_AND}/ui/FighterProfileScreen.kt",
    ], [
        f"{S_SDK}/fighter/Sources/FightDeckFighter/FighterRootView.swift",
    ]),
    ("Shared components (chips, labelled row, action buttons)", [
        (f"{N_IOS}/Design/SharedViews.swift", "PresetChipButton"),
        (f"{N_IOS}/Design/SharedViews.swift", "PresetChipRow"),
        (f"{N_IOS}/Design/SharedViews.swift", "PrimaryActionButton"),
        (f"{N_IOS}/Design/SharedViews.swift", "SecondaryActionButton"),
        (f"{N_IOS}/Design/SharedViews.swift", "KeyboardDoneButton"),
        (f"{N_AND}/ui/CommonUi.kt", "PresetChipButton"),
        (f"{N_AND}/ui/CommonUi.kt", "DetailRow"),
        (f"{N_AND}/ui/CommonUi.kt", "PrimaryActionButton"),
        (f"{N_AND}/ui/CommonUi.kt", "SecondaryActionButton"),
        (f"{N_AND}/ui/CommonUi.kt", "KeyboardDoneButton"),
        (f"{N_AND}/ui/CommonUi.kt", "SectionHeader"),
    ], [
        f"{S_CORE}/PresetChips.swift", f"{S_CORE}/LabeledRow.swift", f"{S_CORE}/ActionControls.swift",
    ]),
    # Demo infrastructure: the other approaches except 02 keep it in the host.
    ("Image server", [
        (f"{N_IOS}/Services/LocalAssetServer.swift", "LocalAssetServer"),
        (f"{N_IOS}/Services/LocalAssetServer.swift", "OneShotContinuation"),
        (f"{N_AND}/services/LocalAssetServer.kt", "LocalAssetServer"),
    ], [
        f"{S_SDK}/events/Sources/FightDeckEvents/AssetServer.swift",
    ]),
    # The palette crossing into the SDK. Skip also keeps each host's own token file, because
    # the hosts' screens still need it, so both are charged here.
    ("Design tokens", [
        f"{N_IOS}/Design/DesignTokens.swift", f"{N_AND}/design/Tokens.kt",
    ], [
        f"{S_CORE}/ThemeTokens.swift", f"{S_CORE}/ThemeColor.swift", f"{S_CORE}/Palette.swift",
        f"{S_CORE}/Typography.swift", f"{S_CORE}/Metrics.swift", f"{S_CORE}/MaterialScheme.swift",
        "04-sdk-skip/ios/FightDeck/Design/DesignTokens.swift",
        "04-sdk-skip/android/app/src/main/java/com/fightdeck/baseline/design/Tokens.kt",
    ]),
]

# Skip files that are part of the SDK but have no native counterpart to line up against.
SEAM = [
    f"{S_SDK}/betslip/Sources/FightDeckBetslip/BetslipHosting.swift",
    f"{S_SDK}/deposit/Sources/FightDeckDeposit/DepositHosting.swift",
    f"{S_SDK}/fighter/Sources/FightDeckFighter/FighterHosting.swift",
    f"{S_CORE}/GroupedList.swift",   # notes only
]

# Shared code whose native counterpart exists but cannot be cut out to line up against: the
# catalogue's load states and loading sit inside the native AppState and MainViewModel, among
# everything else those two hold.
UNMATCHED = [
    f"{S_SDK}/events/Sources/FightDeckEvents/CatalogModel.swift",
]


def count(source) -> int:
    return declaration(*source) if isinstance(source, tuple) else whole(source)


def main() -> None:
    tracked = subprocess.run(["git", "-C", str(ROOT), "ls-files", f"{S_SDK}/*/Sources/**/*.swift"],
                             capture_output=True, text=True, check=True).stdout.split()
    assigned = {s for _, _, skip in GROUPS for s in skip if isinstance(s, str)} | set(SEAM) | set(UNMATCHED)
    missing = [f for f in tracked if f not in assigned]
    if missing:
        sys.exit("unassigned Skip SDK files — add them to a group:\n  " + "\n  ".join(missing))

    rows = []
    for label, native, skip in GROUPS:
        n, s = sum(count(x) for x in native), sum(count(x) for x in skip)
        rows.append((label, n, s))
    width = max(len(r[0]) for r in rows)
    print(f"{'':<{width}}  {'00-native, both':>16}  {'04-sdk-skip, shared':>20}  change")
    for label, n, s in rows:
        print(f"{label:<{width}}  {n:>16,}  {s:>20,}  {100 * (s - n) / n:+.0f}%")
    seam = sum(whole(x) for x in SEAM)
    print(f"\nSkip SDK seam with no native counterpart (Hosting entry points): {seam}")
    unmatched = sum(whole(x) for x in UNMATCHED)
    print(f"Shared, native counterpart not separable (catalogue model): {unmatched}")


if __name__ == "__main__":
    main()
