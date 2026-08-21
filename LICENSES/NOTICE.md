# Attribution and licensing

This repository contains two separately licensed things. Keeping them distinct
matters, because only one of them is ours to license.

## What we authored

The packaging scripts, workflows, option schema, curation overlay and
documentation in this repository are copyright (c) 2026 LANCommander and are
released under the MIT License, in `LICENSE`.

## What we redistribute

The published `.LCX` package contains binaries from **umu-launcher**, which we did
not author and do not license. Those files remain under their own terms:

| | |
|---|---|
| Project | umu-launcher |
| Homepage | https://github.com/Open-Wine-Components/umu-launcher |
| Copyright | (c) Open Wine Components |
| License | GNU General Public License, version 3.0 |

The full upstream license is in `UPSTREAM-LICENSE.txt` and is also packed inside
the payload archive as `COPYING.txt`, so it travels with the binaries rather than
only living here.

### Obligations we carry

**The license travels with the binary.** `source.ps1` copies
`UPSTREAM-LICENSE.txt` into the payload as `COPYING.txt`, so it is present in
every `.LCX` and on every client that installs one.

**Corresponding source (GPLv3 §6).** The `umu-run` we ship is upstream's own
release asset — `umu-launcher-<version>-zipapp.tar`, built by upstream's CI —
redistributed byte-for-byte unmodified. Complete corresponding source for the
exact build is the tree at that tag:

    https://github.com/Open-Wine-Components/umu-launcher/releases/tag/<version>

Every release of this repository records the upstream version it packaged, in its
tag, its release notes and `LastKnownVersion` in `redistributable.yml`, so the
source matching any published package can always be identified. If that upstream
copy ever becomes unavailable, we will supply the complete corresponding source
for any version we have published on request — open an issue.

**We modify nothing.** The zipapp is repackaged, not rebuilt: extracted from
upstream's tar and placed in the payload unchanged. Nothing is patched, recompiled
or stripped.

### Why this payload is distributed the way it is

The GPL permits redistributing an unmodified binary provided the license
accompanies it and corresponding source is offered. Both hold here, so the zipapp
is bundled into the package rather than downloaded on the client — which also
means a LAN party with no internet can still install it.

Nothing of ours is combined with it. The launcher executes `umu-run` as a separate
program through a command template; it is not linked, imported or embedded. The
`.LCX` is mere aggregation on a distribution medium, so the MIT-licensed scripts
and workflows in this repository are not a derived work and remain MIT.

The zipapp additionally embeds umu-launcher's own Python dependencies, among them
`urllib3`, `python-xlib` and `truststore`. Those are upstream's build and
upstream's choice, are under their own permissive and GPL-compatible licenses, and
their sources are available from their respective projects.

**Not bundled:** Proton and Valve's Steam Linux Runtime, which umu-launcher
downloads itself on first launch, under their own terms.

---

If you are the copyright holder for umu-launcher and would prefer this package
not redistribute your files, please open an issue and we will switch it to
downloading from you directly at install time.
