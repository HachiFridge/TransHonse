require 'json'
require 'fileutils'
require 'zip'

# Find all files in translated folder modified within the last N hours
def find_recent_files(hours_ago = 24)
    cutoff_time = Time.now - (hours_ago * 3600)
    recent_files = []

    Dir.glob("data/data/translated/**/*.json").each do |file_path|
        if File.mtime(file_path) >= cutoff_time
            recent_files << file_path
        end
    end

    recent_files.sort_by { |f| File.mtime(f) }
end

# Create zip from file list
def create_recovery_zip(files)
    return if files.empty?

    FileUtils.mkdir_p("output/packages")

    # Find next available number
    zip_number = 1
    while File.exist?("output/packages/update_#{zip_number}.zip")
        zip_number += 1
    end

    zip_filename = "output/packages/update_#{zip_number}.zip"
    puts "Creating #{zip_filename} with #{files.length} file(s)..."

    Zip::File.open(zip_filename, create: true) do |zipfile|
        files.each do |file_path|
            zip_path = file_path.gsub('\\', '/').sub(/^translated\//, '')
            zipfile.add(zip_path, file_path)
            puts "  Added: #{zip_path}"
        end
    end

    puts "Successfully created #{zip_filename}"
end

# Main
puts "How many hours ago were the files translated? (default: 24)"
hours = gets.chomp
hours = hours.empty? ? 24 : hours.to_i

puts "\nSearching for files modified in the last #{hours} hour(s)..."
recent_files = find_recent_files(hours)

if recent_files.empty?
    puts "No files found. Try increasing the time range."
    exit
end

puts "\nFound #{recent_files.length} file(s):"
recent_files.first(10).each do |file|
    puts "  #{file} (#{File.mtime(file)})"
end
puts "  ... and #{recent_files.length - 10} more" if recent_files.length > 10

puts "\nCreate zip with these files? (y/n)"
if gets.chomp.downcase == 'y'
    create_recovery_zip(recent_files)
else
    puts "Cancelled."
end
