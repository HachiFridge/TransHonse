#!/usr/bin/env ruby
require 'json'
require 'fileutils'

# Configuration
LOCALIZED_FOLDER = "localized_data"
OUTPUT_FILE = "Translation_Progress.md"
QC_PROGRESS_FILE = "output/tracking/output/tracking/output/tracking/qc_file_progress.json"

def count_lines_in_json(file_path)
    begin
        content = File.read(file_path)
        return 0 if content.strip.empty?

        json_data = JSON.parse(content)

        # Handle different JSON structures
        if json_data.is_a?(Array)
            return json_data.length
        elsif json_data.is_a?(Hash)
            # Count translatable text entries
            count = 0
            if json_data.key?("list")
                # Character system text or similar structure
                json_data["list"].each do |item|
                    count += 1 if item.is_a?(Hash) && item.key?("text")
                end
            elsif json_data.key?("data")
                # Story/home timeline structure
                json_data["data"].each do |item|
                    if item.is_a?(Hash)
                        count += 1 if item.key?("text")
                        count += 1 if item.key?("choice")
                    end
                end
            else
                # Generic hash - count all key-value pairs
                count = json_data.keys.length
            end
            return count
        end

        return 0
    rescue => e
        puts "Error reading #{file_path}: #{e.message}"
        return 0
    end
end

def organize_files_by_category(base_folder)
    story_groups = {}
    home_groups = {}
    other_files = {
        "Character System Text" => [],
        "Text Data Dictionary" => [],
        "Other Files" => []
    }

    # Find all JSON files
    Dir.glob(File.join(base_folder, "**/*.json")).each do |file_path|
        relative_path = file_path.sub("#{base_folder}/", "")

        # Skip config.json
        next if relative_path == "config.json"

        line_count = count_lines_in_json(file_path)

        file_info = {
            path: relative_path,
            full_path: file_path,
            lines: line_count
        }

        # Categorize and group files
        if relative_path.include?("story/data")
            # Extract: assets/story/data/04/1029/storytimeline_041029001.json
            # Group by: 04 (chapter) -> 1029 (character ID)
            parts = relative_path.split('/')
            chapter = parts[3]  # "04"
            char_id = parts[4]  # "1029"

            story_groups[chapter] ||= {}
            story_groups[chapter][char_id] ||= []
            story_groups[chapter][char_id] << file_info

        elsif relative_path.include?("home/data")
            # Extract: assets/home/data/00000/01/hometimeline_00000_01_1029001.json
            # Group by: 00000 (group) -> 01 (subgroup) -> 1029 (character ID)
            parts = relative_path.split('/')
            group = parts[3]  # "00000"
            subgroup = parts[4]  # "01"

            # Extract character ID from filename
            filename = File.basename(relative_path, '.json')
            if filename =~ /hometimeline_\d+_\d+_(\d{4})/
                char_id = $1

                home_groups[group] ||= {}
                home_groups[group][subgroup] ||= {}
                home_groups[group][subgroup][char_id] ||= []
                home_groups[group][subgroup][char_id] << file_info
            else
                other_files["Other Files"] << file_info
            end

        elsif relative_path.include?("character_system_text")
            other_files["Character System Text"] << file_info
        elsif relative_path.include?("text_data_dict")
            other_files["Text Data Dictionary"] << file_info
        else
            other_files["Other Files"] << file_info
        end
    end

    {
        story: story_groups,
        home: home_groups,
        other: other_files
    }
end

def get_chapter_name(chapter_id)
    chapter_names = {
        "00" => "Short Episodes",
        "01" => "Tutorial Story",
        "02" => "Main Story (Story Mode)",
        "04" => "Uma Stories (Story Mode)",
        "08" => "Story Mode Prologues/Intro",
        "09" => "Event Stories (Story Mode)",
        "10" => "Anniversary Stories",
        "11" => "Uma-specific Campaign Dialogues",
        "12" => "Campaign Popups",
        "13" => "Special/Collab Stories (KIRARI MAGIC SHOW, ...)",
        "14" => "Scenario Intro",
        "40" => "Scenario Story Events",
        "50" => "Uma Training Events",
        "80" => "R Support Card Events",
        "82" => "SR Support Card Events",
        "83" => "SSR Support Card Events"
    }
    chapter_names[chapter_id] || "Chapter #{chapter_id}"
end

def get_home_group_name(group_id)
    group_names = {
        "00000" => "Single Character (1 character)",
        "00001" => "Duo (2 characters)",
        "00002" => "Trio (3 characters)"
    }
    group_names[group_id] || "Group #{group_id}"
end

def load_qc_progress
    return {} unless File.exist?(QC_PROGRESS_FILE)
    begin
        raw_data = JSON.parse(File.read(QC_PROGRESS_FILE))
        # Normalize all paths to use forward slashes
        normalized = {}
        raw_data.each do |path, value|
            normalized_path = path.gsub('\\', '/')
            normalized[normalized_path] = value
        end
        normalized
    rescue => e
        puts "Warning: Could not load QC progress file: #{e.message}"
        {}
    end
end

def calculate_progress(files, qc_data)
    completed = files.count { |f| qc_data[f[:path]] == true }
    total = files.length
    [completed, total]
end

def get_status_emoji(completed, total)
    if completed == 0
        "⬜ Not Started"
    elsif completed == total
        "✅ Completed"
    else
        "🔄 In Progress"
    end
end

def generate_markdown(data, qc_data)
    markdown = []
    markdown << "# Translation QC Progress Tracker"
    markdown << ""
    markdown << "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    markdown << ""
    markdown << "---"
    markdown << ""

    # Calculate totals
    story_total = data[:story].values.flat_map { |chapter| chapter.values }.flatten.length
    home_total = data[:home].values.flat_map { |group| group.values.flat_map { |sg| sg.values } }.flatten.length
    other_total = data[:other].values.flatten.length
    total_files = story_total + home_total + other_total

    # Calculate completed totals
    all_files = data[:story].values.flat_map { |chapter| chapter.values }.flatten +
                data[:home].values.flat_map { |group| group.values.flat_map { |sg| sg.values } }.flatten +
                data[:other].values.flatten
    total_completed = all_files.count { |f| qc_data[f[:path]] == true }

    # Summary section
    markdown << "## Summary"
    markdown << ""
    markdown << "- **Story Files**: #{story_total} files"
    markdown << "- **Home Timeline Files**: #{home_total} files"
    markdown << "- **Other Files**: #{other_total} files"
    markdown << ""
    markdown << "**Total**: #{total_files} files (#{total_completed} QC'd, #{total_files - total_completed} remaining)"
    markdown << ""
    markdown << "---"
    markdown << ""

    # Story Files Section - Each chapter gets its own table
    if !data[:story].empty?
        markdown << "## Story Files"
        markdown << ""

        data[:story].keys.sort.each do |chapter|
            chapter_name = get_chapter_name(chapter)
            total_chapter_files = data[:story][chapter].values.flatten.length

            markdown << "### #{chapter} - #{chapter_name}"
            markdown << ""
            markdown << "Total: #{total_chapter_files} files"
            markdown << ""
            markdown << "| ID | Progress | Status | Notes |"
            markdown << "|----|----------|--------|-------|"

            data[:story][chapter].keys.sort.each do |char_id|
                files = data[:story][chapter][char_id]
                completed, total = calculate_progress(files, qc_data)
                status = get_status_emoji(completed, total)
                markdown << "| #{char_id} | #{completed}/#{total} | #{status} | |"
            end

            markdown << ""
        end
    end

    # Home Timeline Files Section - Grouped by interaction type
    if !data[:home].empty?
        markdown << "## Home Timeline Files"
        markdown << ""

        data[:home].keys.sort.each do |group|
            group_name = get_home_group_name(group)

            # Calculate total for this group
            total_group_files = data[:home][group].values.flat_map { |sg| sg.values }.flatten.length

            markdown << "### #{group_name}"
            markdown << ""
            markdown << "Total: #{total_group_files} files"
            markdown << ""
            markdown << "| ID | Progress | Status | Notes |"
            markdown << "|----|----------|--------|-------|"

            # Flatten all subgroups and collect all character IDs
            all_chars = {}
            data[:home][group].each do |subgroup, chars|
                chars.each do |char_id, files|
                    all_chars[char_id] ||= []
                    all_chars[char_id].concat(files)
                end
            end

            # Sort and display
            all_chars.keys.sort.each do |char_id|
                files = all_chars[char_id]
                completed, total = calculate_progress(files, qc_data)
                status = get_status_emoji(completed, total)
                markdown << "| #{char_id} | #{completed}/#{total} | #{status} | |"
            end

            markdown << ""
        end
    end

    # Other Files Section
    data[:other].each do |category, files|
        next if files.empty?

        markdown << "## #{category}"
        markdown << ""
        markdown << "| File | Lines | Status | Notes |"
        markdown << "|------|-------|--------|-------|"

        files.each do |file|
            display_path = file[:path].gsub("assets/", "")
            markdown << "| `#{display_path}` | #{file[:lines]} | ⬜ Not Started | |"
        end

        markdown << ""
    end

    # Legend
    markdown << "---"
    markdown << ""
    markdown << "## Status Legend"
    markdown << ""
    markdown << "- ⬜ Not Started"
    markdown << "- 🔄 In Progress"
    markdown << "- ✅ Completed"
    markdown << "- ⚠️ Needs Revision"
    markdown << ""
    markdown << "---"
    markdown << ""
    markdown << "## How to Use"
    markdown << ""
    markdown << "1. Update the **Progress** column as you complete files (e.g., 3/7 means 3 of 7 files QC'd)"
    markdown << "2. Update the **Status** column for each character/group"
    markdown << "3. Add notes about issues, patterns, or special considerations"
    markdown << "4. Use the QC workflow script (`qc_workflow.rb`) for detailed line-by-line tracking"
    markdown << "5. Regenerate this file periodically to update counts and add new files"
    markdown << ""

    markdown.join("\n")
end

# Main execution
puts "Scanning #{LOCALIZED_FOLDER} for JSON files..."
data = organize_files_by_category(LOCALIZED_FOLDER)

puts "Loading QC progress..."
qc_data = load_qc_progress

puts "Generating markdown..."
markdown_content = generate_markdown(data, qc_data)

puts "Writing to #{OUTPUT_FILE}..."
File.write(OUTPUT_FILE, markdown_content)

# Calculate statistics
story_groups = data[:story].values.flat_map { |chapter| chapter.keys }.length
story_files = data[:story].values.flat_map { |chapter| chapter.values }.flatten.length
home_groups = data[:home].values.flat_map { |group| group.values.flat_map { |sg| sg.keys } }.length
home_files = data[:home].values.flat_map { |group| group.values.flat_map { |sg| sg.values } }.flatten.length
other_files = data[:other].values.flatten.length

# Calculate completed files
all_files = data[:story].values.flat_map { |chapter| chapter.values }.flatten +
            data[:home].values.flat_map { |group| group.values.flat_map { |sg| sg.values } }.flatten +
            data[:other].values.flatten
total_completed = all_files.count { |f| qc_data[f[:path]] == true }
total_files = story_files + home_files + other_files

puts "Done! Generated QC progress tracker with:"
puts "  - Story Files: #{story_groups} character groups, #{story_files} total files"
puts "  - Home Timeline Files: #{home_groups} character groups, #{home_files} total files"
puts "  - Other Files: #{other_files} files"
puts "\nTotal: #{total_files} files (#{total_completed} QC'd, #{total_files - total_completed} remaining)"
