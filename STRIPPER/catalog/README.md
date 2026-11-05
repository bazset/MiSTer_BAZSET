# STRIPPER RBF catalog

This directory holds the maintained fingerprint catalog for **STRIPPER v0.3**.

- [protected_rbfs.json](./protected_rbfs.json) contains known file SHA-256 hashes and upstream beta-family listings.
- [Raw update URL](https://raw.githubusercontent.com/bazset/MiSTer_BAZSET/main/STRIPPER/catalog/protected_rbfs.json) is the default one-click update source for the Windows application.

## Updating the list

Edit `protected_rbfs.json` on GitHub and commit it. Update `catalog_version` whenever publishing changes. Each exact RBF entry must have a 64-character lowercase SHA-256 checksum and its size in bytes. No executable patches, keys, ROMs, or binary RBFs are stored in this catalog.

The catalog distinguishes **upstream beta-family listings** from **file-specific observations**. A filename match does not establish that a specific RBF is protected; a SHA-256 match only establishes the file's identity. Only report `file_tested_locked: true` when the particular hash has been tested and the behaviour has been observed.

### Local vs online data

STRIPPER downloads the catalog via HTTPS and keeps an offline copy. Personal notes recorded in the application stay in its local `catalog/local_overrides.json` file and **are never uploaded automatically**.

This catalog is solely for identification and testing inventory; it does not provide any means to bypass beta-key checks.
