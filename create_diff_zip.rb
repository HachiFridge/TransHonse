require 'json'
require 'fileutils'
require 'zip'
require 'set'

# Find all files in translated folder that don't exist in reference folder
def find_new_files(translated_dir, reference_dir)
    new_files = []

    # Get all JSON files in translated folder
    Dir.glob(File.join(translated_dir, "**/*.json")).each do |translated_file|
        # Get relative path from translated folder
        relative_path = translated_file.sub("#{translated_dir}/", '').sub("#{translated_dir}\\", '')

        # Check if corresponding file exists in reference folder
        reference_file = File.join(reference_dir, relative_path)

        unless File.exist?(reference_file)
            new_files << translated_file
        end
    end

    new_files.sort
end

# Create zip from file list
def create_diff_zip(files)
    return if files.empty?

    FileUtils.mkdir_p("updates")

    # Find next available number
    zip_number = 1
    while File.exist?("updates/update_#{zip_number}.zip")
        zip_number += 1
    end

    zip_filename = "updates/update_#{zip_number}.zip"
    puts "\nCreating #{zip_filename} with #{files.length} file(s)..."

    Zip::File.open(zip_filename, create: true) do |zipfile|
        files.each do |file_path|
            # Normalize path separators and remove "translated/" prefix
            zip_path = file_path.gsub('\\', '/').sub(/^translated\//, '')
            zipfile.add(zip_path, file_path)
            puts "  Added: #{zip_path}"
        end
    end

    puts "\nSuccessfully created #{zip_filename}"
end

# Main
translated_dir = "translated"
reference_dir = "spootmtlslop_revised_reko"

unless Dir.exist?(translated_dir)
    puts "Error: #{translated_dir} folder not found"
    exit 1
end

unless Dir.exist?(reference_dir)
    puts "Error: #{reference_dir} folder not found"
    exit 1
end

puts "Comparing #{translated_dir} with #{reference_dir}..."
puts "Finding files that exist in #{translated_dir} but not in #{reference_dir}...\n"

new_files = find_new_files(translated_dir, reference_dir)

if new_files.empty?
    puts "No new files found!"
    puts "All files in #{translated_dir} already exist in #{reference_dir}"
    exit
end

puts "Found #{new_files.length} new file(s):"
new_files.first(20).each do |file|
    puts "  #{file}"
end
puts "  ... and #{new_files.length - 20} more" if new_files.length > 20

puts "\nCreate zip with these #{new_files.length} file(s)? (y/n)"
if gets.chomp.downcase == 'y'
    create_diff_zip(new_files)
else
    puts "Cancelled."
end
