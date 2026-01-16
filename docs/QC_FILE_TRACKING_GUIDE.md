# QC File Progress Tracking Guide

## Overview

The QC progress tracker now supports marking individual files as QC'd. Your progress is stored in `qc_file_progress.json` and automatically reflected in the generated `Translation_Progress.md`.

## How to Mark Files as QC'd

### Method 1: Manual JSON Editing (Recommended)

Edit `qc_file_progress.json` and add file paths with `true` value:

```json
{
  "assets/story/data/04/1029/storytimeline_041029001.json": true,
  "assets/story/data/04/1029/storytimeline_041029002.json": true,
  "assets/home/data/00000/01/hometimeline_00000_01_1029001.json": true
}
```

**File Path Format:**
- Story files: `assets/story/data/{chapter}/{char_id}/{filename}.json`
- Home files: `assets/home/data/{group}/{subgroup}/{filename}.json`
- Other files: `character_system_text_dict.json`, `text_data_dict.json`, etc.

### Method 2: Batch Marking

You can use a simple Ruby script to mark all files for a character as completed:

```ruby
require 'json'

# Load current progress
progress = File.exist?('qc_file_progress.json') ? JSON.parse(File.read('qc_file_progress.json')) : {}

# Mark all files for character 1029 in chapter 04 as complete
Dir.glob('localized_data/assets/story/data/04/1029/*.json').each do |file|
  relative_path = file.sub('localized_data/', '')
  progress[relative_path] = true
end

# Save updated progress
File.write('qc_file_progress.json', JSON.pretty_generate(progress))
puts "Updated progress file"
```

## Regenerating the Progress Tracker

After updating `qc_file_progress.json`, regenerate the markdown:

```bash
ruby generate_qc_progress.rb
```

The script will:
1. Load your QC progress from `qc_file_progress.json`
2. Calculate completion stats for each character/group
3. Update status emojis automatically:
   - ⬜ Not Started (0 files QC'd)
   - 🔄 In Progress (some files QC'd)
   - ✅ Completed (all files QC'd)
4. Show overall progress in the summary

## Example Output

After marking some files as complete, you'll see:

```markdown
### 04 - Uma Stories (Story Mode)

Total: 212 files

| ID   | Progress | Status         | Notes |
|------|----------|----------------|-------|
| 1029 | 3/7      | 🔄 In Progress |       |
| 1042 | 7/7      | ✅ Completed   |       |
| 1044 | 0/7      | ⬜ Not Started |       |
```

## Tips

1. **Backup your progress**: `qc_file_progress.json` is in `.gitignore`, so back it up separately
2. **Use version control**: Track your `qc_file_progress.json` in a separate repo if needed
3. **Integrate with QC workflow**: You can modify `qc_workflow.rb` to automatically update this file when you mark files as approved
4. **Bulk operations**: Use scripts to mark entire chapters or character groups at once

## File Structure

```
TransHonse/
├── generate_qc_progress.rb      # Main script
├── qc_file_progress.json        # Your QC progress (gitignored)
├── Translation_Progress.md      # Generated progress report
└── localized_data/              # Source files
    └── assets/
        ├── story/
        └── home/
```
