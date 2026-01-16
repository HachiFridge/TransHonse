#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to update all path references in Ruby and Python scripts
# after repository reorganization
class PathUpdater
  # Comprehensive path mappings covering all patterns found
  PATH_MAPPINGS = {
    # Directory paths - quoted strings
    '"raw"' => '"data/raw"',
    "'raw'" => "'data/raw'",
    '"translated"' => '"data/translated"',
    "'translated'" => "'data/translated'",
    '"references"' => '"data/references"',
    "'references'" => "'data/references'",
    '"mdb_extract"' => '"data/raw/mdb"',
    "'mdb_extract'" => "'data/raw/mdb'",
    '"updates"' => '"output/packages"',
    "'updates'" => "'output/packages'",

    # Directory paths - with trailing slashes
    'raw/' => 'data/raw/',
    'translated/' => 'data/translated/',
    'references/' => 'data/references/',
    'mdb_extract/' => 'data/raw/mdb/',
    'updates/' => 'output/packages/',

    # Config files
    '"config.toml"' => '"config/config.toml"',
    "'config.toml'" => "'config/config.toml'",
    'config.toml' => 'config/config.toml',
    'TomlRB.load_file("config.toml")' => 'TomlRB.load_file("config/config.toml")',
    "TomlRB.load_file('config.toml')" => "TomlRB.load_file('config/config.toml')",

    '"dictionary.json"' => '"config/dictionary.json"',
    "'dictionary.json'" => "'config/dictionary.json'",
    'dictionary.json' => 'config/dictionary.json',

    # Output files
    '"qc_progress.json"' => '"output/tracking/qc_file_progress.json"',
    "'qc_progress.json'" => "'output/tracking/qc_file_progress.json'",
    '"qc_file_progress.json"' => '"output/tracking/qc_file_progress.json"',
    "'qc_file_progress.json'" => "'output/tracking/qc_file_progress.json'",
    'qc_progress.json' => 'output/tracking/qc_file_progress.json',
    'qc_file_progress.json' => 'output/tracking/qc_file_progress.json',

    '"translation_errors.log"' => '"output/logs/translation_errors.log"',
    "'translation_errors.log'" => "'output/logs/translation_errors.log'",
    'translation_errors.log' => 'output/logs/translation_errors.log',

    # Python Path objects
    'Path("raw")' => 'Path("data/raw")',
    "Path('raw')" => "Path('data/raw')",
    'Pathname.new("raw")' => 'Pathname.new("data/raw")',
    "Pathname.new('raw')" => "Pathname.new('data/raw')",
  }.freeze

  # Patterns that need special regex-based replacement
  REGEX_PATTERNS = [
    # translated/**/*.json patterns
    { pattern: /"translated\/\*\*\/\*\.json"/, replacement: '"data/translated/**/*.json"' },
    { pattern: /'translated\/\*\*\/\*\.json'/, replacement: "'data/translated/**/*.json'" },

    # Default parameter values
    { pattern: /\(raw_folder\s*=\s*"raw"\)/, replacement: '(raw_folder = "data/raw")' },
    { pattern: /\(translated_folder\s*=\s*"translated"\)/, replacement: '(translated_folder = "data/translated")' },
    { pattern: /raw_folder\s*=\s*"raw"/, replacement: 'raw_folder = "data/raw"' },
    { pattern: /translated_folder\s*=\s*"translated"/, replacement: 'translated_folder = "data/translated"' },

    # File.join patterns
    { pattern: /File\.join\("translated",/, replacement: 'File.join("data/translated",' },
    { pattern: /File\.join\('translated',/, replacement: "File.join('data/translated'," },
    { pattern: /File\.join\("raw",/, replacement: 'File.join("data/raw",' },
    { pattern: /File\.join\('raw',/, replacement: "File.join('data/raw'," },
  ].freeze

  def initialize(dry_run: false)
    @dry_run = dry_run
    @files_updated = []
    @changes_by_file = {}
  end

  def run
    puts "=" * 70
    puts "TransHonse Path Updater - Comprehensive Mode"
    puts "=" * 70
    puts "Mode: #{@dry_run ? 'DRY RUN (no changes)' : 'LIVE (will modify files)'}"
    puts ""

    # Find all Ruby and Python scripts (both in root and scripts/)
    scripts = find_all_scripts

    if scripts.empty?
      puts "WARNING: No scripts found!"
      puts "This might mean migration hasn't been run yet, or no scripts exist."
      exit 1
    end

    puts "Found #{scripts.size} scripts to check"
    puts ""

    scripts.each do |script|
      update_file(script)
    end

    # Update config
    update_config

    print_summary
  end

  private

  def find_all_scripts
    scripts = []

    # Scripts in scripts/ directory (after migration)
    scripts.concat(Dir.glob('scripts/**/*.{rb,py}'))

    # Scripts still in root (before migration or during migration)
    scripts.concat(Dir.glob('*.{rb,py}').reject do |f|
      f.start_with?('migrate_structure') ||
      f.start_with?('update_script_paths') ||
      f.start_with?('test_structure')
    end)

    scripts.uniq.sort
  end

  def update_file(filepath)
    return unless File.exist?(filepath)

    content = File.read(filepath)
    original_content = content.dup
    changes = []

    # Apply simple string replacements
    PATH_MAPPINGS.each do |old_path, new_path|
      count = content.scan(old_path).size
      if count > 0
        content.gsub!(old_path, new_path)
        changes << { from: old_path, to: new_path, count: count }
      end
    end

    # Apply regex-based replacements
    REGEX_PATTERNS.each do |pattern_info|
      matches = content.scan(pattern_info[:pattern])
      if matches.any?
        content.gsub!(pattern_info[:pattern], pattern_info[:replacement])
        changes << {
          from: pattern_info[:pattern].inspect,
          to: pattern_info[:replacement],
          count: matches.size,
          type: 'regex'
        }
      end
    end

    # Special handling for script-specific issues
    content = fix_script_specific_issues(content, filepath, changes)

    if content != original_content
      @changes_by_file[filepath] = changes

      if @dry_run
        puts "  [DRY RUN] Would update: #{filepath}"
        puts "    Changes:"
        changes.each do |change|
          if change[:type] == 'regex'
            puts "      - Pattern #{change[:from]} (#{change[:count]}x)"
          else
            puts "      - #{change[:from]} → #{change[:to]} (#{change[:count]}x)"
          end
        end
      else
        File.write(filepath, content)
        puts "  ✓ Updated: #{filepath}"
        puts "    Applied #{changes.size} change type(s)"
        @files_updated << filepath
      end
      puts ""
    end
  end

  def fix_script_specific_issues(content, filepath, changes)
    # Fix relative path issues for scripts in subdirectories
    basename = File.basename(filepath)

    case basename
    when 'translate.rb'
      # Ensure all MDB paths use new structure
      if content.include?('mdb_extract/')
        content.gsub!('mdb_extract/', 'data/raw/mdb/')
        changes << { from: 'mdb_extract/', to: 'data/raw/mdb/', count: content.scan('data/raw/mdb/').size }
      end

    when 'extract.py'
      # Fix Python Path default
      if content.match?(/default=Path\(/)
        # Already handled by REGEX_PATTERNS
      end

    when 'qc_workflow.rb'
      # Fix default folder parameters
      # Already handled by REGEX_PATTERNS
    end

    content
  end

  def update_config
    config_path = 'config/config.toml'

    # Also check if config is still in root (before migration)
    unless File.exist?(config_path)
      if File.exist?('config.toml')
        config_path = 'config.toml'
      else
        puts "⚠ Config file not found at config/config.toml or config.toml"
        puts ""
        return
      end
    end

    puts "Updating configuration file: #{config_path}..."

    content = File.read(config_path)
    original_content = content.dup
    changes = []

    # Update existing path references
    config_updates = {
      'raw_folder = "raw"' => 'raw_folder = "data/raw"',
      'raw_folder = \'raw\'' => 'raw_folder = "data/raw"',

      'char_system_text_raw = "character_system_text.json"' =>
        'char_system_text_raw = "data/raw/mdb/character_system_text.json"',

      'char_system_text_raw = "raw/character_system_text.json"' =>
        'char_system_text_raw = "data/raw/mdb/character_system_text.json"',

      'char_system_text_reference = "mdb_extract/character_system_text.json"' =>
        'char_system_text_reference = "data/references/character_system_text_dict_reference.json"',

      'char_system_text_reference = "references/' =>
        'char_system_text_reference = "data/references/',
    }

    config_updates.each do |old, new_val|
      if content.include?(old)
        content.gsub!(old, new_val)
        changes << "#{old} → #{new_val}"
      end
    end

    # Add new configuration paths if they don't exist
    additions = []

    unless content.match?(/translated_folder\s*=/)
      # Find insertion point after raw_folder or in [server] section
      if content.include?('raw_folder =')
        insertion_point = content.index(/raw_folder = .*$/)
        insertion_point = content.index("\n", insertion_point) if insertion_point
        if insertion_point
          content.insert(insertion_point, "\ntranslated_folder = \"data/translated\"")
          additions << "translated_folder"
        end
      end
    end

    unless content.match?(/output_folder\s*=/)
      if content.include?('translated_folder =')
        insertion_point = content.index(/translated_folder = .*$/)
        insertion_point = content.index("\n", insertion_point) if insertion_point
        if insertion_point
          content.insert(insertion_point, "\noutput_folder = \"output/packages\"")
          additions << "output_folder"
        end
      end
    end

    unless content.match?(/error_log\s*=/)
      content << "\n\n# Output paths\n" unless content.include?('# Output paths')
      content << "error_log = \"output/logs/translation_errors.log\"\n"
      content << "qc_progress = \"output/tracking/qc_file_progress.json\"\n"
      additions << "error_log, qc_progress"
    end

    unless content.match?(/master_mdb\s*=/)
      content << "\n# Game files\n" unless content.include?('# Game files')
      content << "master_mdb = \"data/game/master.mdb\"\n"
      content << "meta_db = \"data/game/meta_decrypted.sqlite\"\n"
      additions << "master_mdb, meta_db"
    end

    if content != original_content
      if @dry_run
        puts "  [DRY RUN] Would update: #{config_path}"
        puts "    Path updates: #{changes.size}" if changes.any?
        changes.each { |c| puts "      - #{c}" }
        puts "    New additions: #{additions.join(', ')}" if additions.any?
      else
        File.write(config_path, content)
        puts "  ✓ Updated: #{config_path}"
        puts "    Path updates: #{changes.size}" if changes.any?
        puts "    New additions: #{additions.join(', ')}" if additions.any?
        @files_updated << config_path
      end
    else
      puts "  ℹ Config already up to date"
    end

    puts ""
  end

  def print_summary
    puts ""
    puts "=" * 70
    puts "Update Summary"
    puts "=" * 70
    puts ""

    if @dry_run
      puts "This was a DRY RUN. No files were modified."
      puts ""
      puts "Files that would be updated: #{@changes_by_file.size}"

      if @changes_by_file.any?
        puts ""
        puts "Change breakdown:"
        all_changes = @changes_by_file.values.flatten
        total_replacements = all_changes.sum { |c| c[:count] || 1 }
        puts "  Total string replacements: #{total_replacements}"

        # Group by type
        by_pattern = all_changes.group_by { |c| c[:from] }
        puts ""
        puts "  Most common changes:"
        by_pattern.sort_by { |_, v| -v.sum { |c| c[:count] || 1 } }.first(10).each do |from, changes|
          total = changes.sum { |c| c[:count] || 1 }
          to = changes.first[:to]
          puts "    #{from} → #{to} (#{total}x across #{changes.size} files)"
        end
      end

      puts ""
      puts "Run without --dry-run to apply changes."
    else
      puts "✓ Successfully updated #{@files_updated.size} files"
      puts ""

      if @files_updated.any?
        puts "Updated files:"
        @files_updated.each { |f| puts "  - #{f}" }
      end

      puts ""
      puts "Next steps:"
      puts "1. Review changes: git diff"
      puts "2. Run structure test: ruby test_structure.rb"
      puts "3. Test extraction: python scripts/extraction/extract.py --help"
      puts "4. Test translation: ruby scripts/translation/translate.rb"
      puts "5. Verify config: cat config/config.toml"
      puts ""
      puts "If everything looks good, commit the changes!"
    end
    puts ""
  end
end

# Main execution
if __FILE__ == $0
  dry_run = ARGV.include?('--dry-run') || ARGV.include?('-n')

  if ARGV.include?('--help') || ARGV.include?('-h')
    puts "TransHonse Path Update Script (Comprehensive Version)"
    puts ""
    puts "This script updates ALL path references in Ruby and Python scripts"
    puts "to match the new reorganized repository structure."
    puts ""
    puts "It handles:"
    puts "  - Simple string replacements (\"raw\" → \"data/raw\")"
    puts "  - Path objects (Path(\"raw\") → Path(\"data/raw\"))"
    puts "  - Default parameters (raw_folder = \"raw\")"
    puts "  - File.join() calls"
    puts "  - Config file references"
    puts "  - Glob patterns (translated/**/*.json)"
    puts ""
    puts "Usage: ruby update_script_paths.rb [OPTIONS]"
    puts ""
    puts "Options:"
    puts "  --dry-run, -n    Show what would be done without making changes"
    puts "  --help, -h       Show this help message"
    puts ""
    puts "This script should be run AFTER migrate_structure.rb moves the files."
    puts ""
    puts "Examples:"
    puts "  ruby update_script_paths.rb --dry-run  # Preview changes"
    puts "  ruby update_script_paths.rb             # Apply changes"
    exit 0
  end

  updater = PathUpdater.new(dry_run: dry_run)
  updater.run
end
