# Icon attribution

## Public-domain icons

Sourced from [Wikimedia Commons](https://commons.wikimedia.org), not from either game's
own artwork -- this repo ships no copyrighted Battlespire/Redguard box art or in-game
assets. Used in the game-mode picker (`GameMode.swift` / `RootView.swift`).

| File | Represents | Source | Author | License |
|---|---|---|---|---|
| `battlespire-sword.svg` | Battlespire | [File:Sword 01.svg](https://commons.wikimedia.org/wiki/File:Sword_01.svg) | Nick1915 (via Open Clip Art Library) | CC0 1.0 Universal |
| `redguard-scimitar.svg` | Redguard | [File:Scimitar.svg](https://commons.wikimedia.org/wiki/File:Scimitar.svg) | Greentubing~commonswiki; design update by Jpgibert | Public domain |

None of these licenses legally require attribution, but it's kept here anyway so the
provenance of every bundled asset stays traceable if a license or file ever needs to be
swapped out.

## Steam and GOG logos -- trademarked, used for identification only

`steam-logo.svg` and `gog-logo.png` are Valve's and GOG sp. z o.o.'s
actual registered logos, used in the Setup Wizards' "Steam" / "GOG" source-picker buttons
(`OnboardingWizard.swift`, `RedguardOnboardingWizard.swift`) purely to identify which
install method each button is for -- this app is not affiliated with, sponsored by, or
endorsed by either company.

- `steam-logo.svg` -- Valve's Steam icon logo, downloaded from
  [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Steam_icon_logo.svg).
  Commons notes the mark "may be protected as a trademark in some jurisdictions" --
  usage here is nominative (naming a real, distinct install source), not primary branding,
  which is the same basis other third-party launchers (Heroic, Lutris, Playnite, etc.)
  rely on. Valve's own branding guidelines are at
  [partner.steamgames.com/doc/marketing/branding](https://partner.steamgames.com/doc/marketing/branding)
  for anyone who wants to double check usage before distributing this app further.
- `gog-logo.png` -- GOG's official "GOG.COM" logo, downloaded from their
  press kit at [gog.com/pressroom/press-kit](https://www.gog.com/pressroom/press-kit/).
  Same nominative-use basis as above.

If this app is ever distributed at any real scale, it's worth a quick sanity check against
each company's current guidelines (they can change), but for an unaffiliated open-source
launcher labeling its own buttons, this is standard practice.
