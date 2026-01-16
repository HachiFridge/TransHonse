require 'json'
require 'fileutils'

def fix_json_file(file_path)
    begin
        # Read the file content
        content = File.read(file_path)

        # Check if it starts with a quote (double-encoded)
        if content.strip.start_with?('"')
            puts "Fixing: #{file_path}"

            # First parse: removes the outer JSON encoding
            decoded_string = JSON.parse(content)

            # Second parse: get the actual JSON object
            json_object = JSON.parse(decoded_string)

            # Write back properly formatted
            File.write(file_path, JSON.pretty_generate(json_object))

            return true
        else
            # File is already properly formatted
            return false
        end
    rescue JSON::ParserError => e
        puts "ERROR parsing #{file_path}: #{e.message}"
        return false
    rescue => e
        puts "ERROR processing #{file_path}: #{e.message}"
        return false
    end
end

# Main
puts "Scanning translated folder for double-encoded JSON files...\n"

fixed_count = 0
skipped_count = 0
error_count = 0

Dir.glob("data/data/translated/**/*.json").each do |file_path|
    result = fix_json_file(file_path)

    if result == true
        fixed_count += 1
    elsif result == false
        skipped_count += 1
    else
        error_count += 1
    end
end

puts "\nSummary:"
puts "Fixed: #{fixed_count} file(s)"
puts "Skipped (already correct): #{skipped_count} file(s)"
puts "Errors: #{error_count} file(s)" if error_count > 0
puts "\nAll files have been processed!"
