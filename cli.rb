require 'thor'
require 'fileutils'
require 'httparty'
require 'open3'
require 'json'

class CollamaCLI < Thor
  OLLAMA_MODEL = "llama3.2" # Default model

  def self.start(*args)
    ensure_ollama_running
    @ollama_model = OLLAMA_MODEL
    super(*args, no_commands: true) # Suppress Thor commands display
  end

  private

  def self.ensure_ollama_running
    puts "Checking if Ollama is running..."
    output, status = Open3.capture2("pgrep -f ollama")

    if status.success?
      puts "Ollama is already running."
    else
      puts "Starting Ollama..."
      system("ollama serve &")
      sleep(2) # Give Ollama some time to start
      puts "Ollama started."
    end
    puts "You can use 'index [file or dir]' to add a file or directory to the RAG system."
  end

  private

  def ollama_query(input)
    indexer = FileIndexer.new
    search_results = indexer.ft_search_files(input)
    context = search_results.map.with_index do |row, idx|
      <<~CHUNK
      [#{idx + 1}] File: #{row["path"]}
      #{row["content"][0..500]}...
      CHUNK
    end.join("\n\n")

    prompt = <<~PROMPT
      You are an assistant that helps with technical questions based on the user's local files.

      Question:
      #{input}

      Use the following context from the user's files to answer:

      #{context}

      Be specific, quote code where helpful, and keep the answer concise.
    PROMPT

    url = "http://localhost:11434/api/generate"
    body = {
      model: OLLAMA_MODEL,
      prompt: prompt,
      stream: false,
    }.to_json

    headers = {
      "Content-Type" => "application/json"
    }

    response = HTTParty.post(url, body: body, headers: headers)

    if response.code == 200
      response.parsed_response["response"]
    else
      "Error: Unable to process the request. Status: #{response.code}"
    end
  end
end

CollamaCLI.start(ARGV)