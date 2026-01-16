# Error Logging Guide

## Overview

The translation script now includes comprehensive error logging to help track and diagnose issues during translation.

## Error Log File

**Location:** `translation_errors.log`

**Format:** Daily rotating log file
- Creates new file each day with timestamp
- Keeps historical logs for debugging
- Format: `[YYYY-MM-DD HH:MM:SS] SEVERITY: Message`

## What Gets Logged

### File-Level Errors
- **Empty files** - Files with no content
- **Missing files** - Files that don't exist
- **JSON parsing errors** - Malformed JSON
- **Missing required fields** - Files without text_block_list

### Translation Errors
- **Title translation failures** - When story/home title translation fails
- **Line translation failures** - When dialogue translation fails
- **Choice translation failures** - When choice option translation fails
- **MDB translation failures** - When MDB file entries fail

### Each Error Includes
- **Timestamp** - When the error occurred
- **Context** - What file/line/choice caused the error
- **Error Type** - Exception class (JSON::ParserError, etc.)
- **Error Message** - Specific error description
- **Details** - Additional context (text being translated, etc.)
- **Backtrace** - First 3 lines of stack trace for debugging

## Error Handling Behavior

### Empty/Invalid Files
The script will:
1. Log a warning
2. Skip the file
3. Continue processing other files
4. Count as "skipped" in final summary

### Translation Failures
The script will:
1. Log the error with full context
2. Skip that specific line/choice/entry
3. Continue with next item
4. Increment error counter
5. Still save the file with successfully translated content

### Critical Errors
For file-level failures:
1. Log the error
2. Skip entire file
3. Continue with next file
4. Show error count in summary

## Reading Error Logs

### Example Error Entry
```
[2025-12-16 14:23:45] ERROR: Line translation failed in raw/story/data/00/0001/storytimeline_000001001.json line 15 - StandardError: API timeout
  Details: {}
  Backtrace: translate.rb:108:in `translate_api'
  translate.rb:131:in `block (3 levels) in iterate_json'
  translate.rb:93:in `each_with_index'
```

### What This Tells You
- **When:** 2:23 PM on Dec 16, 2025
- **What:** Translation failed for line 15
- **Where:** In storytimeline_000001001.json
- **Why:** API timeout error
- **How:** In the translate_api function

## Error Summary

After translation completes, you'll see:
```
Files processed: 150
Files Skipped: 5
Errors: 3
Total batch time: 45.23 seconds.

All tasks complete
WARNING: 3 error(s) occurred during translation
Check translation_errors.log for details
```

## Common Error Scenarios

### Empty JSON Files
```
WARNING: File is empty, skipping
```
**Action:** Check if extraction script created empty files, re-extract if needed.

### Missing text_block_list
```
WARNING: No text_block_list found, skipping
```
**Action:** File structure is incorrect, verify extraction process.

### API Errors
```
ERROR: Line translation failed - API timeout
```
**Action:** Check LLM server is running, check network connectivity.

### JSON Parse Errors
```
ERROR: JSON parsing failed - unexpected token
```
**Action:** File may be corrupted or partially written, re-extract.

## Best Practices

1. **Check logs after each batch** - Review translation_errors.log after large translation runs

2. **Monitor error counts** - If errors are increasing, investigate before continuing

3. **Fix root causes** - Don't just re-run, understand why errors occurred

4. **Keep historical logs** - Log files rotate daily, old logs are preserved

5. **Test with small batches first** - Validate setup works before large runs

## Log Rotation

- **Daily rotation** - New log file created each day
- **Naming:** `translation_errors.log.YYYYMMDD`
- **Old logs preserved** - Historical logs kept for reference
- **Automatic cleanup** - Configure in script if needed

## Debugging Tips

1. **Search by file path** - Find all errors for specific file:
   ```bash
   grep "storytimeline_000001001.json" translation_errors.log
   ```

2. **Filter by error type**:
   ```bash
   grep "JSON::ParserError" translation_errors.log
   ```

3. **Count errors**:
   ```bash
   grep "ERROR:" translation_errors.log | wc -l
   ```

4. **View recent errors**:
   ```bash
   tail -50 translation_errors.log
   ```

## Integration with Workflow

The error log integrates with your workflow:

1. **Translation** - Errors logged in real-time
2. **Summary** - Error count shown at end
3. **Review** - Check log file for details
4. **Fix** - Correct issues (API, files, etc.)
5. **Re-run** - Only failed items if needed

## Error Prevention

To minimize errors:

1. **Verify LLM server is running** before starting
2. **Test API connection** with small batch
3. **Check file structure** of extracted files
4. **Monitor disk space** for log files
5. **Use reference files** to skip re-translating
