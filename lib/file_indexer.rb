require "sqlite3"
require "fileutils"

class FileIndexer
  attr_reader :db

  def initialize(db_path = "db/file_index.db")
    @db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    setup_schema
  end

  def setup_schema
    db.execute_batch <<-SQL
      CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY,
        path TEXT UNIQUE,
        content TEXT,
        summary TEXT,
        last_indexed_at DATETIME
      );

      CREATE VIRTUAL TABLE IF NOT EXISTS file_fts USING fts5(path, content);
    SQL
  end

  # Index a single file
  def index_file(path)
    return unless File.file?(path)
    return unless readable_text_file?(path)
  
    content = File.read(path, encoding: "UTF-8", invalid: :replace, undef: :replace, replace: "?")
  
    db.transaction
    db.execute("INSERT OR REPLACE INTO files (path, content, last_indexed_at) VALUES (?, ?, datetime('now'))", [path, content])
    db.execute("INSERT OR REPLACE INTO file_fts (path, content) VALUES (?, ?)", [path, content])
    db.commit
  
    puts "Indexed: #{path}"
  rescue => e
    puts "❌ Error indexing #{path}: #{e.message}"
  end
  

  # Index all files in a directory recursively
  def index_directory(dir)
    Dir.glob("#{dir}/**/*").each do |file|
      index_file(file)
    end
  end

  # Check if a file is a plain text-based file (e.g. .txt, .md, .rb, etc.)
  def readable_text_file?(path)
    ext = File.extname(path).downcase
    %w[.txt .md .rb .py .js .json .yml .yaml .html .css .sh .log .xml .csv].include?(ext)
  end

  # List indexed files
  def list_files
    db.execute("SELECT path, last_indexed_at FROM files").each do |row|
      puts "#{row['path']} (#{row['last_indexed_at']})"
    end
  end

  # Search by keyword (basic for now)
  def search_files(keyword)
    db.execute("SELECT path, content FROM files WHERE content LIKE ?", ["%#{keyword}%"])
  end

  def ft_search_files(query)
    # Preprocess the query to adhere to FTS5 syntax
    sanitized_query = query.gsub("'", "''") # Escape single quotes
    tokens = sanitized_query.split.map { |word| "\"#{word}\"" } # Wrap each word in double quotes
    formatted_query = tokens.join(" OR ") # Combine tokens with OR operator

    sql = "SELECT path, content FROM file_fts WHERE content MATCH '#{formatted_query}'"
    db.execute(sql)
  end
end
