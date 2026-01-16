# Reference Files Guide

## Overview

The translation script uses reference files to enable incremental translation updates. This allows you to:
- Skip already translated content
- Only translate new entries
- Maintain consistent translations across updates

## Folder Structure

```
TransHonse/
├── mdb_extract/          # Raw MDB files from game
│   ├── character_system_text.json
│   ├── text_data_dict.json
│   └── ...
├── references/           # Your reference translations
│   ├── character_system_text.json
│   ├── text_data_dict.json
│   └── ...
└── translated/           # Output folder
    ├── character_system_text.json
    ├── text_data_dict.json
    └── ...
```

## How It Works

### 1. First Translation (No References)

```bash
ruby translate.rb
# Choose 'm' for MDB
# Select file (e.g., option 1 for character_system_text.json)
```

**What happens:**
- Script looks for `references/character_system_text.json`
- Not found → "No reference file found. Will create new translations."
- Translates ALL entries
- Saves to `translated/character_system_text.json`

### 2. Create Reference File

After your first translation, copy it to the references folder:

```bash
# Create references folder if it doesn't exist
mkdir references

# Copy your translated file as reference
cp translated/character_system_text.json references/character_system_text.json
```

Or copy all MDB files at once:
```bash
cp translated/text_data_dict.json references/
cp translated/localize_dict.json references/
cp translated/race_jikkyo_comment.json references/
# etc...
```

### 3. Incremental Updates (With References)

When game updates with new content:

```bash
# Extract new MDB files (they now have new entries)
# Run translation again
ruby translate.rb
# Choose 'm' for MDB
# Select same file
```

**What happens:**
- Script loads `references/character_system_text.json`
- Compares each entry with reference
- **Entry exists in reference** → Copy translation, skip API call
- **Entry is new** → Translate with LLM
- Saves combined result to `translated/character_system_text.json`

### Example Output

```
Reading mdb_extract/character_system_text.json JSON file...
Category: 1001
[1]: 既存のテキスト
Translation already exists. Skipping.
[2]: 既存のテキスト2
Translation already exists. Skipping.
[3]: 新しいテキスト
[3]: New text here
Lines processed: 1
Lines Skipped: 2
```

## MDB File Reference Names

Each MDB file type has its corresponding reference file:

| MDB File | Reference File |
|----------|---------------|
| character_system_text.json | references/character_system_text.json |
| text_data_dict.json | references/text_data_dict.json |
| localize_dict.json | references/localize_dict.json |
| text_data.json | references/text_data.json |
| race_jikkyo_message.json | references/race_jikkyo_message.json |
| race_jikkyo_comment.json | references/race_jikkyo_comment.json |

## Best Practices

### 1. Keep References Clean
- Only use QC'd, approved translations as references
- Don't use machine-translated references without review
- Update references after manual corrections

### 2. Version Control (Optional)
Keep old references when game updates significantly:
```bash
# Backup current reference before updating
cp references/text_data_dict.json references/text_data_dict_v1.0.json

# Update reference with new version
cp translated/text_data_dict.json references/text_data_dict.json
```

### 3. Workflow for Updates

```
1. Game Update Released
   ↓
2. Extract new MDB files
   ↓
3. Run translation (uses existing references)
   ↓
4. QC new translations
   ↓
5. Update reference files
   ↓
6. Create update zip
```

### 4. Manual Edits to References

If you manually correct translations:

```bash
# Option 1: Edit reference file directly
vim references/character_system_text.json
# Make your corrections
# Next translation will use your corrected version

# Option 2: Edit translated file, then update reference
vim translated/character_system_text.json
# Make corrections
cp translated/character_system_text.json references/
```

## Config File Reference (for character_system_text)

The `config.toml` also has a reference path setting:

```toml
char_system_text_reference = "references/character_system_text.json"
```

**Note:** You may need to update this if you're using the old path.

## Troubleshooting

### "Reference file JSON parsing failed"
**Problem:** Reference file is corrupted or malformed
**Solution:**
```bash
# Check JSON validity
ruby -e "require 'json'; JSON.parse(File.read('references/character_system_text.json'))"

# If invalid, restore from backup or translated folder
cp translated/character_system_text.json references/
```

### "No reference file found" (but file exists)
**Problem:** File is in wrong location
**Solution:**
```bash
# Check file location
ls references/character_system_text.json

# If in wrong place, move it
mv translated/character_system_text_reference.json references/character_system_text.json
```

### All entries being re-translated
**Problem:** Reference file structure doesn't match
**Solution:**
- Ensure reference file uses same JSON structure as raw file
- For nested structures, both keys must match exactly
- Check for extra/missing nesting levels

## Migration from Old System

If you have existing reference files in `translated/` folder with `_reference` suffix:

```bash
# Create references folder
mkdir references

# Move old reference files
mv translated/character_system_text_dict_reference.json references/character_system_text.json
mv translated/text_data_dict_reference.json references/text_data_dict.json
mv translated/localize_dict_reference.json references/localize_dict.json
mv translated/text_data_reference.json references/text_data.json
mv translated/race_jikkyo_message_reference.json references/race_jikkyo_message.json
mv translated/race_jikkyo_comment_reference.json references/race_jikkyo_comment.json
```

## Benefits of Reference System

1. **Cost Savings** - Don't re-translate existing content
2. **Consistency** - Same text always gets same translation
3. **Speed** - Skip API calls for known content
4. **Quality** - Manual corrections preserved across updates
5. **Tracking** - Easy to see what's new (check skip vs. processed counts)

## Example Workflow

```bash
# First time setup
ruby translate.rb  # Translate everything
mkdir references
cp translated/*.json references/

# Game update (3 months later)
# Extract new MDB files to mdb_extract/
ruby translate.rb  # Only translates new entries
# Check logs: "Lines processed: 45, Lines Skipped: 1203"
# Only 45 new lines translated!

# QC new translations
ruby qc_workflow.rb

# Update references
cp translated/character_system_text.json references/

# Create update zip
ruby create_diff_zip.rb
```
