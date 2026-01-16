# TransHonse Scripts Guide

## Translation Scripts

### translate.rb
Main translation script that processes raw game files and translates them using LLM.

**Usage:**
```bash
ruby translate.rb
```

**Options:**
- `f` or `folder` - Translate files in the raw folder (story/home files)
- `m` or `mdb` - Translate MDB files (opens submenu)
- (blank) - Translate both

**MDB File Submenu:**
When you select MDB translation, you can choose:
1. character_system_text.json - Character voice lines and system messages
2. text_data_dict.json - UI text and error messages
3. localize_dict.json - Localization strings
4. text_data.json - General text data
5. race_jikkyo_message.json - Race commentary messages
6. race_jikkyo_comment.json - Race comments
7. All MDB files - Translate all at once
0. Cancel

**Features:**
- Skips already translated files using reference files
- Translates story titles, character names, dialogue text, and choices
- Handles both nested (character_system_text) and flat (race_jikkyo) JSON structures
- Creates numbered update zips of newly translated files
- Tracks translation progress with line counts

**Fixed Issues:**
- ✓ Double JSON encoding (now saves properly formatted JSON)
- ✓ MDB translations now save correctly with reference file support

---

## Utility Scripts

### qc_workflow.rb
Interactive quality check workflow for reviewing translations.

**Usage:**
```bash
ruby qc_workflow.rb
```

**On startup, you'll be asked:**
- Raw folder path (default: `raw`)
- Translated folder path (default: `translated`)

**Features:**
1. **Side-by-side comparison** - View Japanese and English together
2. **Line-level tracking** - Track how many lines QC'd per file
3. **File status tracking** - Mark files as: not_reviewed, in_progress, needs_revision, approved
4. **Progress reports** - See overall QC statistics
5. **Export needs revision list** - Generate file list for files needing fixes

**Menu Options:**
1. Review next file - Auto-picks next unreviewed file
2. Review specific file - Jump to any file
3. Show progress report - See statistics
4. List files by status - Filter by status
5. Export files needing revision - Create text file list
6. Exit

**Data Storage:**
- Progress saved to `qc_progress.json`
- Can stop and resume anytime

---

### create_diff_zip.rb
Creates a zip file with files that exist in `translated` but not in a reference folder.

**Usage:**
```bash
ruby create_diff_zip.rb
```

**Configuration:**
- Edit line 55 to set reference folder (currently: `spootmtlslop_revised_reko`)
- Creates numbered zips in `updates/` folder

**Use Case:**
Perfect for creating update packs with only new translations compared to a previous release.

---

## Extraction Scripts

### extract.py
Extracts game assets from Uma Musume to JSON format.

**Usage:**
```bash
python extract.py -t story    # Extract story files
python extract.py -t home     # Extract home files
```

**Common Options:**
- `-t TYPE` - Asset type (story, home, lyrics, preview)
- `-O` - Overwrite existing files (default: skip existing)
- `-w N` - Number of worker threads (default: 4)
- `-dst PATH` - Output directory (default: raw)

**Features:**
- Automatically skips already extracted files (unless `-O` used)
- Parallel processing with configurable workers
- Supports encrypted database decryption

---

## Configuration

### config.toml
Main configuration file for translation settings.

**Key Settings:**
- `api_url` - LLM API endpoint
- `model` - Model name
- `temperature` - Translation randomness (0.1 = consistent)
- `raw_folder` - Source files location
- `char_system_text_raw` - Character system text input file
- `char_system_text_reference` - Reference translations file
- `system_prompt` - Translation instructions for LLM

---

## Workflow Recommendations

### Initial Translation Workflow
1. Extract game files: `python extract.py -t story`
2. Translate files: `ruby translate.rb` → choose option, create update zip
3. Test in game

### Quality Check Workflow
1. Run QC tool: `ruby qc_workflow.rb`
2. Review files and mark status
3. Export files needing revision
4. Fix issues in files
5. Re-run through QC

### Update Workflow
1. Extract new game files
2. Translate only new files (script auto-skips existing)
3. Create diff zip: `ruby create_diff_zip.rb`
4. Distribute update zip

---

## Tips

**Performance:**
- Extract: 4-8 workers is optimal for most systems
- Translate: Single-threaded (LLM bottleneck, no benefit from parallel)

**Quality:**
- Update dictionary.json with character names and terminology
- Review system_prompt in config.toml for translation style
- Use QC workflow to track progress systematically

**File Management:**
- Keep reference folders for creating differential updates
- qc_progress.json preserves your review progress
- Update zips are numbered automatically (update_1.zip, update_2.zip, etc.)
