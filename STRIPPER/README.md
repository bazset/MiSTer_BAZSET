# STRIPPER MiSTer v0.2 — native RBF catalogue scanner and future updater hooks

STRIPPER is now a **MiSTer Linux shell script**, not a Windows program. It scans
`_Arcade/cores` by filename and SHA-256 **without decoding RBFs**.

## Install

Extract the ZIP into your MiSTer SD card root so these paths exist:

- `/media/fat/Scripts/STRIPPER.sh`
- `/media/fat/Scripts/STRIPPER/catalog.tsv`
- `/media/fat/Scripts/STRIPPER/beta_families.txt`
- `/media/fat/Scripts/STRIPPER/catalog.local.tsv`
- `/media/fat/Scripts/STRIPPER/ui.sh` (progress bar and download heartbeat)
- `/media/fat/Scripts/STRIPPER/hooks.sh` (future update features)
- `/media/fat/Scripts/STRIPPER/update_hooks.conf` (both future updates OFF)
- `/media/fat/Scripts/STRIPPER/unlockable.tsv` (empty until verified)

Run **STRIPPER** from MiSTer's Scripts menu to access the text menu.
From SSH / terminal: `sh /media/fat/Scripts/STRIPPER.sh scan`.
For network updates: `sh /media/fat/Scripts/STRIPPER.sh update`.
For the full filesystem-hash scan: `sh /media/fat/Scripts/STRIPPER.sh scan --all`.
To list known entries: `sh /media/fat/Scripts/STRIPPER.sh list`.

## Fast lookup

1. If a filename is an upstream Jotego beta family or present in the local
   catalogue, hash it; skip unrelated filenames.
2. SHA-256 exact match => identify a **known binary version**.
3. Family name match but unknown hash => report unrecognized version.
4. Unknown/unlisted name => skip in fast mode; check with `scan --all`.

There is **no automatic access-control bypass and no RBF patching** in v0.2.
Being listed as a beta family does not prove that the precise RBF includes
an active key circuit. Likewise, an unknown version might still require a key.

## GitHub updates

Maintained version catalogue:
https://github.com/bazset/MiSTer_BAZSET/blob/main/STRIPPER/catalog.tsv

Authoritative beta-family list:
https://github.com/jotego/jtcores/blob/master/.beta.yaml

The `update` command downloads data-only HTTPS files from GitHub, validates
their format, then replaces the local catalogue. It never downloads code to
execute and never changes RBFs. `catalog.local.tsv` remains untouched.

Maintain the local file by appending tab-separated lines in this format:
`sha256<TAB>filename.rbf<TAB>BETA_FAMILY_LISTED<TAB>your_source`

A hash tells STRIPPER which exact bitstream it has found; it does **not**
provide a key or an unlock recipe. Do not label a lock as confirmed without
a separate source/hardware verification.

## Planned unlocked output layout

The PC-only staging tests now generate:
- `_Test/_Arcade/cores/jtcps3_unlocked.rbf` from an independently verified changed candidate.
- `_Test/_Arcade/_Stripped/JoJo's Venture (unlocked).mra`, etc.

For the final MiSTer design, `_Test` is omitted and the same relative paths
start at `/media/fat/_Arcade/`. The original MRAs/cores are never overwritten.
A `(unlocked)` label is only an output naming convention: it does not prove
that controls work. Real CPS3 RBF modification is still unimplemented.

## Future GitHub update hooks

- `SCRIPT_VERSION_CHECK_ENABLED=0`: may eventually check a published script-version feed.
- `UNLOCKABLE_FEED_ENABLED=0`: may eventually retrieve a list of independently
  verified patchable exact RBF versions.
- Both checks are **disabled by default**, and there is NO auto script install.
- Existing catalogue `update` is available and prints live progress/heartbeat.

### Development and validation

Source workspace:
`MisterCores/BAZSET/STRIPPER_MiSTer/`

Shell tested under MSYS2 and on a folder containing 9 user RBF samples;
8 exact hashes matched, 1 unrelated name skipped. The live GitHub update
fetched 9 hashes and 8 current beta families. Native MiSTer hardware test
is still pending, and the tool is not a replacement for the Mistery decoder.
