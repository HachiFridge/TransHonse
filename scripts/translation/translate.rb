require 'json'
require 'uri'
require 'httparty'
require 'toml-rb'
require 'fileutils'
require 'zip'
require 'logger'

# Initialize error logger
$error_logger = Logger.new('output/logs/output/logs/output/logs/translation_errors.log', 'daily')
$error_logger.level = Logger::INFO
$error_logger.formatter = proc do |severity, datetime, progname, msg|
    "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

def log_error(context, error, details = {})
    error_msg = "#{context} - #{error.class}: #{error.message}"
    error_msg += "\n  Details: #{details.inspect}" unless details.empty?
    error_msg += "\n  Backtrace: #{error.backtrace.first(3).join("\n  ")}" if error.backtrace
    $error_logger.error(error_msg)
    puts "ERROR: #{context} - #{error.message}"
end

config = TomlRB.load_file('config/config/config/config.toml')
$server = config['server']
$url = $server['api_url']
puts $url
dictionary = File.read('config/config/config/dictionary.json')
$dictionary_str = JSON.parse(dictionary)
$file_count = 0
$skip_count = 0
$error_count = 0
$newly_translated_files = []

def iterate_json(file_path)
    begin
        puts "Reading #{file_path} JSON File..."
        file = File.read(file_path)

        # Check for empty file
        if file.strip.empty?
            puts "WARNING: File is empty, skipping"
            $error_logger.warn("Empty file: #{file_path}")
            $skip_count += 1
            return
        end

        file_json = JSON.parse(file)

        # Check if text_block_list exists
        unless file_json['text_block_list']
            puts "WARNING: No text_block_list found, skipping"
            $error_logger.warn("Missing text_block_list: #{file_path}")
            $skip_count += 1
            return
        end

        text = file_json['text_block_list']

        # Check if text_block_list is empty
        if text.empty?
            puts "WARNING: text_block_list is empty, skipping"
            $error_logger.warn("Empty text_block_list: #{file_path}")
            $skip_count += 1
            return
        end

        sliced_path = file_path.byteslice(4, 256)
        output_path = File.join("data/translated", sliced_path)
        output_dir = File.dirname(output_path)
        FileUtils.mkdir_p(output_dir)

        if File.exist?(output_path)
            puts "#{sliced_path} already exists, skipping"
            $skip_count += 1
            return
        end

        title = file_json["title"]
        if title && !title.empty?
            begin
                enTitle = translate_api(title)
                file_json["title"] = enTitle
                puts "Story Title: #{enTitle}"
            rescue => e
                log_error("Title translation failed for #{file_path}", e)
                $error_count += 1
            end
        else
            puts "No title"
        end

        text.each_with_index do |text, text_index|
            begin
                #raw line info
                puts "Raw Line ##{text_index}"
                puts "Name: #{text["name"]}"
                puts "Text: #{text["text"]}"

                #name translation logic
                if (text["name"] == 'モノローグ' or text["name"] == '') #checks if the name is a monologue blank
                    text["text"] = ''
                    enName = ''
                else
                    enName = translate_api(text['name'])
                end
                #text translation logic
                enText = translate_api(text['text'])
                puts "Translated Line ##{text_index}"
                puts "Name: #{enName}\nText: #{enText}"
                #write to save
                text["name"] = enName
                text["text"] = enText

                (text['choice_data_list'] || []).each_with_index do |choices, choice_index|
                    begin
                        #raw choices info
                        puts "Raw Choice ##{choice_index}:"
                        puts "Text: #{choices}"
                        #choice translation logic
                        enChoice = translate_api(choices)
                        puts "Translated Choice #{choice_index}: #{enChoice}"
                        #write to save
                        text['choice_data_list'][choice_index] = enChoice
                    rescue => e
                        log_error("Choice translation failed in #{file_path} line #{text_index} choice #{choice_index}", e)
                        $error_count += 1
                    end
                end
            rescue => e
                log_error("Line translation failed in #{file_path} line #{text_index}", e)
                $error_count += 1
            end
        end

        File.write(output_path, JSON.pretty_generate(file_json))
        puts "Saved to: #{output_path}"
        $file_count += 1
        $newly_translated_files << output_path
    rescue JSON::ParserError => e
        log_error("JSON parsing failed for #{file_path}", e)
        $error_count += 1
    rescue => e
        log_error("File processing failed for #{file_path}", e)
        $error_count += 1
    end
end

def translate_mdb_file(raw_file, output_file, reference_file = nil)
    begin
        batch_start_time = Time.now
        puts "Reading #{raw_file} JSON file..."

        if !File.exist?(raw_file)
            puts "File #{raw_file} not found."
            $error_logger.error("File not found: #{raw_file}")
            return
        end

        raw_content = File.read(raw_file)

        # Check for empty file
        if raw_content.strip.empty?
            puts "WARNING: File is empty, skipping"
            $error_logger.warn("Empty MDB file: #{raw_file}")
            $skip_count += 1
            return
        end

        file_raw_json = JSON.parse(raw_content)

        # Check if JSON is empty
        if file_raw_json.nil? || file_raw_json.empty?
            puts "WARNING: JSON is empty, skipping"
            $error_logger.warn("Empty JSON in MDB file: #{raw_file}")
            $skip_count += 1
            return
        end

        file_ref_json = {}
        reference_toggle = false

        # Load reference file if provided and exists
        if reference_file && File.exist?(reference_file)
            begin
                content = File.read(reference_file)
                if content.strip.empty?
                     puts "Reference file is empty. Disabling referencing."
                else
                     file_ref_json = JSON.parse(content)
                     reference_toggle = true
                end
            rescue JSON::ParserError => e
                log_error("Reference file JSON parsing failed: #{reference_file}", e)
                puts "Warning: Could not parse reference file, proceeding without it."
            end
        else
            puts "No reference file found. Will create new translations."
        end

        # Check structure - could be nested (character_system_text) or flat (race_jikkyo_comment)
        is_nested = file_raw_json.values.first.is_a?(Hash)

        if is_nested
            # Nested structure like character_system_text or text_data_dict
            file_raw_json.each do |outer_id, messages_hash|
                puts "Category: #{outer_id}"
                messages_hash.each do |msg_id, text|
                    begin
                        puts "[#{msg_id}]: #{text}"

                        # Check if translation exists in reference file
                        reference_text = file_ref_json.dig(outer_id, msg_id)

                        if reference_text and reference_toggle == true
                            # Use existing translation from reference
                            puts "Translation already exists. Skipping."
                            file_raw_json[outer_id][msg_id] = reference_text
                            $skip_count += 1
                        else
                            # Translate new text
                            enText = translate_api(text)
                            file_raw_json[outer_id][msg_id] = enText
                            puts "[#{msg_id}]: #{enText}"
                            $file_count += 1
                        end
                    rescue => e
                        log_error("MDB translation failed for [#{outer_id}][#{msg_id}] in #{raw_file}", e, {text: text})
                        $error_count += 1
                    end
                end
            end
        else
            # Flat structure like race_jikkyo_comment
            file_raw_json.each do |msg_id, text|
                begin
                    puts "[#{msg_id}]: #{text}"

                    # Check if translation exists in reference file
                    reference_text = file_ref_json[msg_id]

                    if reference_text and reference_toggle == true
                        # Use existing translation from reference
                        puts "Translation already exists. Skipping."
                        file_raw_json[msg_id] = reference_text
                        $skip_count += 1
                    else
                        # Translate new text
                        enText = translate_api(text)
                        file_raw_json[msg_id] = enText
                        puts "[#{msg_id}]: #{enText}"
                        $file_count += 1
                    end
                rescue => e
                    log_error("MDB translation failed for [#{msg_id}] in #{raw_file}", e, {text: text})
                    $error_count += 1
                end
            end
        end

        FileUtils.mkdir_p("data/translated")
        File.write(output_file, JSON.pretty_generate(file_raw_json))
        puts "Completed translating #{raw_file}"
        $newly_translated_files << output_file if $file_count > 0
        batch_end_time = Time.now
        batch_duration = batch_end_time - batch_start_time
        puts "Lines processed: #{$file_count}"
        puts "Lines Skipped: #{$skip_count}"
        puts "Total batch time: #{'%.2f' % batch_duration} seconds."
        $file_count = 0
        $skip_count = 0
    rescue JSON::ParserError => e
        log_error("JSON parsing failed for MDB file: #{raw_file}", e)
        $error_count += 1
    rescue => e
        log_error("MDB file processing failed: #{raw_file}", e)
        $error_count += 1
    end
end

def translate_mdb_menu()
    mdb_files = {
        "1" => {name: "character_system_text.json", ref: "character_system_text.json"},
        "2" => {name: "text_data_dict.json", ref: "text_data_dict.json"},
        "3" => {name: "localize_dict.json", ref: "localize_dict.json"},
        "4" => {name: "text_data.json", ref: "text_data.json"},
        "5" => {name: "race_jikkyo_message.json", ref: "race_jikkyo_message.json"},
        "6" => {name: "race_jikkyo_comment.json", ref: "race_jikkyo_comment.json"}
    }

    puts "\n=== MDB File Translation ==="
    puts "Select which file(s) to translate:"
    puts "  1. character_system_text.json"
    puts "  2. text_data_dict.json"
    puts "  3. localize_dict.json"
    puts "  4. text_data.json"
    puts "  5. race_jikkyo_message.json"
    puts "  6. race_jikkyo_comment.json"
    puts "  7. All MDB files"
    puts "  0. Cancel"
    print "\nChoice: "

    choice = gets.chomp

    if choice == "0"
        puts "Cancelled."
        return
    elsif choice == "7"
        # Translate all files
        mdb_files.each do |key, file_info|
            raw_path = "data/data/raw/mdb/#{file_info[:name]}"
            output_path = "data/data/translated/#{file_info[:name]}"
            ref_path = "data/data/references/#{file_info[:ref]}"

            if File.exist?(raw_path)
                translate_mdb_file(raw_path, output_path, ref_path)
            else
                puts "Skipping #{file_info[:name]} (not found)"
            end
        end
    elsif mdb_files.key?(choice)
        # Translate selected file
        file_info = mdb_files[choice]
        raw_path = "data/data/raw/mdb/#{file_info[:name]}"
        output_path = "data/data/translated/#{file_info[:name]}"
        ref_path = "data/data/references/#{file_info[:ref]}"

        if File.exist?(raw_path)
            translate_mdb_file(raw_path, output_path, ref_path)
        else
            puts "File #{raw_path} not found!"
        end
    else
        puts "Invalid choice."
    end
end

def translate_api(rawText)
    payload = {
        model: $server['model'],
        temperature: $server['temperature'],
        messages: [
            {
                role: 'system',
                content: "#{$server['system_prompt']} Refer to below for a dictionary in json format with the order japanese_text : english_text. (example\"ミホノブルボン\": \"Mihono Bourbon\", which means translate ミホノブルボン to Mihono Bourbon. \n #{$dictionary_str} \n translate the below text",
            },
            {
                role: 'user',
                content: rawText
            }
        ],
        top_p: $server['top_p'],
        top_k: $server['top_k'],
        repetition__penalty: $server['repetition_penalty']
    }

    attempts = 0
    last_response = nil
    while attempts <= $server['retry_attempts']
        response = HTTParty.post($url,
            body: payload.to_json,
            headers:{'Content-Type' => 'application/json'},
        )
        returned_response = response["choices"][0]['message']['content']
        if returned_response.include?("###")
            attempts += 1
            last_response = returned_response
            puts "Found junk output, retrying... (Attempt #{attempts})"
        else
            return returned_response
        end
    end

    # If we exit the loop, all retries failed - try to clean the last response
    if last_response
        # Try to extract clean text by removing junk patterns
        cleaned = last_response.dup

        # Remove common junk patterns
        cleaned = cleaned.gsub(/###\s*(Response|Translation|Output|Answer)\s*:?\s*/i, '')
        cleaned = cleaned.gsub(/^###.*$/, '')  # Remove lines starting with ###
        cleaned = cleaned.strip

        # Check if cleaned version is valid (not empty and doesn't still contain ###)
        if !cleaned.empty? && !cleaned.include?("###")
            text_preview = rawText.length > 50 ? "#{rawText[0..50]}..." : rawText
            $error_logger.warn("Cleaned junk output for text: #{text_preview}")
            $error_logger.warn("  Original: #{last_response[0..100]}...")
            $error_logger.warn("  Cleaned: #{cleaned[0..100]}...")
            puts "WARNING: Used cleaned response after removing junk markers"
            return cleaned
        end
    end

    # Complete failure - couldn't clean the response
    error_msg = "Translation failed after #{$server['retry_attempts']} attempts - all responses contained junk output"
    text_preview = rawText.length > 50 ? "#{rawText[0..50]}..." : rawText
    log_error(error_msg, StandardError.new("Junk output in all retry attempts"), {text: text_preview})
    $error_count += 1
    raise StandardError.new(error_msg)
end

def create_update_zip()
    return if $newly_translated_files.empty?
    FileUtils.mkdir_p("output/packages")

    # Find next available number
    zip_number = 1
    while File.exist?("output/packages/update_#{zip_number}.zip")
        zip_number += 1
    end

    zip_filename = "output/packages/update_#{zip_number}.zip"
    puts "\nCreating #{zip_filename} with #{$newly_translated_files.length} file(s)..."

    Zip::File.open(zip_filename, create: true) do |zipfile|
        $newly_translated_files.each do |file_path|
            zip_path = file_path.gsub('\\', '/').sub(/^translated\//, '')
            zipfile.add(zip_path, file_path)
            puts "  Added: #{zip_path}"
        end
    end

    puts "Successfully created #{zip_filename}"
end

def trans_loop(target_folder)
    unless Dir.exist?(target_folder)
        puts "Folder does not exist"
        $error_logger.error("Target folder does not exist: #{target_folder}")
        return
    end

    puts "Running through all files in \"#{target_folder}\""
    batch_start_time = Time.now

    Dir.glob(File.join(target_folder, "**/*.json")).each do |file_path|
        iterate_json(file_path)
    end

    batch_end_time = Time.now
    batch_duration = batch_end_time - batch_start_time
    puts "Files processed: #{$file_count}"
    puts "Files Skipped: #{$skip_count}"
    puts "Errors: #{$error_count}" if $error_count > 0
    puts "Total batch time: #{'%.2f' % batch_duration} seconds."
    $file_count = 0
    $skip_count = 0
    $error_count = 0
end

def main()
    puts "TransHonse LLM Slop"
    puts "==================="
    puts "Translate Folder (f), MDB Files (m), or leave blank for both."
    print "Choice: "
    input = gets.chomp.downcase

    puts "\nCreate update zip after translation? (y/n)"
    create_zip = gets.chomp.downcase == 'y'

    total_errors = 0

    if input == "folder" || input == "f"
        trans_loop($server['raw_folder'])
        total_errors += $error_count
    elsif input == "mdb" || input == "m"
        translate_mdb_menu()
        total_errors += $error_count
    elsif input == ""
        trans_loop($server['raw_folder'])
        total_errors += $error_count
        translate_mdb_menu()
        total_errors += $error_count
    end

    puts "\nAll tasks complete"
    if total_errors > 0
        puts "WARNING: #{total_errors} error(s) occurred during translation"
        puts "Check output/logs/output/logs/translation_errors.log for details"
    end
    create_update_zip() if create_zip
end

main()

