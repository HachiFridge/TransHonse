# TransHonse Quick Start Guide

## Repository Structure (Post-Reorganization)

```
TransHonse/
├── scripts/          # All executable scripts
├── data/             # Game data (raw, translated, references)
├── config/           # Configuration files
├── docs/             # Documentation
├── output/           # Generated files (packages, logs)
└── archive/          # Old versions and backups
```

## First Time Setup

### 1. Install Dependencies

**Ruby:**
```bash
bundle install
```

**Python:**
```bash
pip install -r requirements.txt
```

### 2. Configure Settings

Edit [config/config.toml](config/config.toml):
- Set your LLM API endpoint (`api_url`)
- Configure model settings
- Adjust system prompt if needed

### 3. Add Game Files

Place your game database files in `data/game/`:
- `master.mdb` - Main game database
- `meta_decrypted.sqlite` - Metadata database (optional)

## Common Workflows

### Extract Game Files

**Extract story files:**
```bash
python scripts/extraction/extract.py -t story
```

**Extract home interaction files:**
```bash
python scripts/extraction/extract.py -t home
```

**Extract MDB data (character voices, UI text, etc):**
```bash
ruby scripts/extraction/extract_mdb.rb data/game/master.mdb
```

All extracted files go to `data/raw/`

### Translate Files

```bash
ruby scripts/translation/translate.rb
```

You'll be prompted to choose:
- Translate folder files (story/home)
- Translate MDB files
- Or both

Translations are saved to `data/translated/` and update packages to `output/packages/`

### Quality Check (QC)

```bash
ruby scripts/qc/qc_workflow.rb
```

Interactive workflow to:
- Review translations side-by-side with originals
- Mark files as reviewed/approved/needs revision
- Track progress per file
- Export list of files needing fixes

Progress saved to `output/tracking/qc_file_progress.json`

### Create Update Package

```bash
ruby scripts/packaging/create_diff_zip.rb
```

Creates a numbered update zip in `output/packages/` containing only files that differ from your reference version.

## Directory Reference

### `data/raw/`
Raw extracted game files (Japanese original text)
- `story/` - Story event files
- `home/` - Home interaction files
- `lyrics/` - Song lyrics
- `mdb/` - MDB database extracts (character text, UI, etc)

### `data/translated/`
Your English translations (mirror structure of `raw/`)
- `story/` - Translated stories
- `home/` - Translated home interactions
- `mdb/` - Translated MDB data

### `data/references/`
Reference translation files for comparison/dictionary
- `character_system_text_dict_reference.json`
- `text_data.json`

### `data/game/`
Original game database files
- `master.mdb`
- `meta_decrypted.sqlite`
- `sqlite3mc_x64.dll`

### `output/packages/`
Generated update zip files
- `update_1.zip`, `update_2.zip`, etc.

### `output/logs/`
Error logs and debug output
- `translation_errors.log`

### `output/tracking/`
Progress tracking files
- `qc_file_progress.json`

## Typical Translation Workflow

1. **Extract new game files**
   ```bash
   python scripts/extraction/extract.py -t story -O
   ```
   `-O` flag overwrites existing (use for game updates)

2. **Translate extracted files**
   ```bash
   ruby scripts/translation/translate.rb
   ```
   Choose option (folder/mdb/both)

3. **Review translations**
   ```bash
   ruby scripts/qc/qc_workflow.rb
   ```
   QC your translations, mark status

4. **Fix any issues**
   Edit files in `data/translated/` directly

5. **Create distribution package**
   ```bash
   ruby scripts/packaging/create_diff_zip.rb
   ```
   Creates numbered update zip

6. **Test in game**
   Copy files from zip to game directory and test

## Tips

- **Logs**: Check `output/logs/translation_errors.log` if translation fails
- **Config**: Edit `config/dictionary.json` to add character names/terms
- **Testing**: Keep old versions in `archive/releases/` for comparison
- **Backups**: Reference files in `data/references/` prevent re-translating

## Troubleshooting

**"Cannot find config.toml"**
- Make sure you're in the repository root
- Config is now at `config/config.toml`

**"Raw files not found"**
- Extract game files first: `python scripts/extraction/extract.py -t story`
- Check files exist in `data/raw/story/` or `data/raw/home/`

**"Translation API error"**
- Check your API endpoint in `config/config.toml`
- Make sure your LLM server is running
- Check logs in `output/logs/`

**"Permission denied on scripts"**
- Make scripts executable: `chmod +x scripts/**/*.{rb,py}`
- Or run with interpreter: `ruby scripts/translation/translate.rb`

## More Documentation

- [SCRIPTS_GUIDE.md](docs/SCRIPTS_GUIDE.md) - Detailed script usage
- [QC_FILE_TRACKING_GUIDE.md](docs/QC_FILE_TRACKING_GUIDE.md) - QC workflow guide
- [REFERENCE_FILES_GUIDE.md](docs/REFERENCE_FILES_GUIDE.md) - Reference file format
- [REORGANIZATION_PLAN.md](REORGANIZATION_PLAN.md) - Structure details

## Need Help?

Check the guide files in the `docs/` folder or review the scripts themselves - they include helpful comments and usage instructions.
