# Chemistry index pipeline (v0.29)

This pipeline builds `data/chem_index/*.json`, which the game bundles. It runs offline at build time only. The game never goes online for it and ships no key.

```bash
# Materials Project crystals. The key comes from MP_API_KEY or .runtime/secrets/mp_api_key (gitignored).
python dev/chem_index/fetch_mp.py
# PubChem molecules (no key)
python dev/chem_index/fetch_pubchem.py
# Rebuild from the cache in .runtime/chem_index_cache/ without network
python dev/chem_index/fetch_mp.py --offline
python dev/chem_index/fetch_pubchem.py --offline
```

- **Never commit the key.** Never print or log it, and never put it anywhere under `data/`.
- The element list comes from `data/elements.json`. Rerun both scripts when elements are added.
- Attribution and licences are in `data/chem_index/sources.json`, and the game's 数据来源与致谢 screen shows them. Keep that file in step with any new source.
- Design and matching rules: `notes/11-index.md`.
