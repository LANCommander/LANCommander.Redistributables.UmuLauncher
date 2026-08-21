# LANCommander.Redistributables.UmuLauncher

Automatically built LANCommander redistributable import package (`.LCX`) for
[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher).

umu-launcher runs Windows games on Linux through Proton. It is the standalone
entry point into Valve's Steam Linux Runtime, so a non-Steam game gets the same
container, the same Proton build and the same per-game fixes Steam applies to its
own library — without Steam installed. Attach it to Windows-only games that your
Linux clients need to run.

This is a **compatibility shim**, not a runtime installer. Rather than installing
something a game then finds on its own, it wraps the game's launch command.

## Install it

Download `redistributable.lcx` from the [latest release][latest] and import it
through your LANCommander server's **Redistributables** page, or from the CLI:

```
LANCommander.Launcher.CLI Import --Path redistributable.lcx --Type Redistributable
```

Then assign it to the games that need it, either from the game's
**Redistributables** field or from this redistributable's **Games** field.

Re-importing a newer release **updates** the existing entry rather than creating a
second one, because the identifiers in `redistributable.yml` are stable across
releases.

Alternatively, import once and let it update itself: the package ships a `Package`
script, which a LANCommander server runs on a schedule to pull new versions
straight from this repository's releases.

[latest]: https://github.com/LANCommander/LANCommander.Redistributables.UmuLauncher/releases/latest

### Client requirements

| | |
|---|---|
| **Linux only** | Every client-side script is marked `Platforms: Linux`. See the warning below about mixed-platform games. |
| **Python 3.10+** | `umu-run` is a Python zipapp: it bundles umu and its dependencies but not an interpreter. The Install script fails with a clear message if `python3` is missing. |
| **Disk and bandwidth** | The first launch downloads Proton and the Steam Linux Runtime — expect 1–2 GB, with no progress shown in LANCommander. Pre-warm clients before an event, or see `Update the Runtime` below. |

## What it installs

Only umu-launcher itself, and only into the game's own metadata directory at
`{InstallDir}/.lancommander/{RedistributableId}/Files/`. Nothing is written to the
game directory, to `~/.local/bin`, or anywhere system-wide.

| File | |
|---|---|
| `umu-run` | The upstream zipapp, redistributed unmodified (~420 KB) |
| `COPYING.txt` | The upstream GPLv3 text |

Proton and the Steam Linux Runtime are **not** bundled — umu-launcher downloads
those itself on first launch, into its own XDG directories, where they are shared
across every game.

The game is then launched through a command template:

```
python3 "{InstallDir}/.lancommander/<id>/Files/umu-run" "{exe}" {args}
```

## Options

Nine options, all of which reach umu-launcher as environment variables.

| Option | | Default |
|---|---|---|
| **Game Identity** | | |
| `GAMEID` | Identifier umu uses to find per-game Proton fixes in its games database | `umu-default` |
| `STORE` | Storefront this copy came from — only meaningful alongside a real Game ID | *(unset)* |
| `WINEPREFIX` | The game's virtual Windows install: registry, runtimes, saved files | `{InstallDir}/.umu` |
| **Proton** | | |
| `PROTONPATH` | A path, version name (`GE-Proton9-5`) or codename (`GE-Proton`) | *(unset — umu uses UMU-Proton)* |
| `PROTON_VERB` | How Proton starts the executable | `waitforexitandrun` |
| **Runtime** | | |
| `UMU_RUNTIME_UPDATE` | Whether to check for a newer Steam Linux Runtime each launch | `1` |
| `UMU_HTTP_TIMEOUT` | Seconds to wait on each download request | `5` |
| `UMU_HTTP_RETRIES` | How many times to retry a failed download | `3` |
| **Diagnostics** | | |
| `UMU_LOG` | umu's own logging — set to `1` or `debug` when a game will not start | `0` |

Administrators can override any of these per game from the game's
**Redistributables** page. Values resolve as schema default, then per-game value,
then per-action override.

Two are worth setting deliberately:

- **`GAMEID`** is what unlocks per-game Proton fixes. Look the title up in the
  [umu database][umudb] and set its `umu-` id per game; the default applies no
  fixes at all.
- **`WINEPREFIX`** defaults to a prefix inside the game's own directory, which is
  the one place this package deviates from upstream (umu would use
  `$HOME/Games/umu/$GAMEID`). That keeps games isolated from one another and lets
  the Uninstall script clean the prefix up. Point several games at one path to
  share a prefix — the Uninstall script will then leave it alone, since it only
  ever deletes a prefix inside the game directory it is uninstalling.

For an event with poor connectivity, set **`UMU_RUNTIME_UPDATE`** to `0` to pin
every client to the runtime it already has.

`UMU_NO_PROTON` is deliberately not exposed. umu tests it with `!= "1"` in one
place and with bare truthiness in another, and `"0"` is truthy in Python — an
administrator switching it "off" would switch it on.

[umudb]: https://umu.openwinecomponents.org/

### Mixed-platform games

`GuestPlatforms` gates which *actions the launcher offers*, but the command
template is applied on whatever host the game launches from. Attaching this
redistributable to a game that Windows clients also launch will break that
game on Windows. Keep it on Linux-only entries, or on games your Windows clients
do not run.

## What is in the package

| Path | |
|---|---|
| `Manifest.yml` | Redistributable metadata, including the embedded option schema |
| `Archives/{guid}` | A ZIP of the payload, extracted into the game's `.lancommander` metadata directory |
| `Scripts/{guid}` | One entry per PowerShell script |

## How this repository works

| File | Purpose |
|---|---|
| `redistributable.yml` | Identity, payload source, stable script GUIDs |
| `source.ps1` | Resolves the upstream release and extracts the zipapp from its tar |
| `Schema.Overlay.yml` | The whole option schema, written by hand |
| `OptionSchema.yml` | Generated from the overlay. Do not edit by hand |
| `Scripts/*.ps1` | DetectInstall, Install, Uninstall and the server-side Package updater |
| `LICENSES/` | Upstream attribution and license text |

Unusually for a redistributable in this family, `Schema.Overlay.yml` is not
curation layered over a parsed config — it *is* the schema. umu-launcher reads no
configuration file (it accepts a TOML file only when passed `--config`), so
`ConfigPaths` is empty and every option is hand-written.

`OptionSchema.yml` is still generated, and the build fails if the committed copy
does not match what the overlay produces. To regenerate it locally:

```powershell
Import-Module <path-to>/LANCommander.Redistributables/module/LANCommander.Redistributables
Invoke-RedistributableBuild -RepositoryPath . -UpdateSchema
```

Edit `Schema.Overlay.yml`; never edit `OptionSchema.yml`, since the next rebuild
overwrites it.

### Staying current

A scheduled workflow checks umu-launcher for new versions. When one appears it
rebuilds the payload from the new release and opens a pull request; merging it
publishes the release.

Because the option set is hand-written rather than parsed, a new **environment
variable** upstream adds will not appear on its own — it has to be added to
`Schema.Overlay.yml`. Upstream documents them in `docs/umu.1.scd`, which is worth
a look when a release bumps the minor version.

## Licensing

The scripts and workflows here are MIT licensed. umu-launcher itself is GPLv3 and
is not ours — see [`LICENSES/NOTICE.md`](LICENSES/NOTICE.md) for attribution, the
obligations we carry, and where to obtain the corresponding source.
