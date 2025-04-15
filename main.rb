require_relative 'lib/file_indexer'
require_relative 'cli'
require 'tty-prompt'

prompt = TTY::Prompt.new

puts "Hello, Dave! How can I help you today?"

loop do
  input = prompt.ask("👦🏻 You:")
  break if input.nil? || input.strip.downcase == 'bye' || input.strip.downcase == 'exit'

  case input.strip.downcase
  when /index (.+)/
    path = input.match(/index (.+)/)[1]
    start_time = Time.now
    begin
      indexer = FileIndexer.new
      if File.directory?(path)
        indexer.index_directory(path)
      elsif File.file?(path)
        indexer.index_file(path)
      else
        puts "❌ Error: Invalid file or directory: #{path}"
        next
      end
      elapsed_time = Time.now - start_time
      puts "✅ Indexed: #{path} in #{elapsed_time.round(2)} seconds"
    rescue => e
      puts "❌ Error indexing #{path}: #{e.message}"
    end
  else
    # Default to chatting with Ollama
    response = CollamaCLI.new.send(:ollama_query, input)
    puts "🤖 Collama: #{response}"
  end
end

puts "Goodbye, Dave!"

# Ensure the Ollama process is terminated when exiting
at_exit do
  puts "Shutting down Ollama..."
  system("pkill -f ollama")
end