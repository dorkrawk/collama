require 'fileutils'
require_relative 'lib/file_indexer'

# Ensure the db/ directory exists
FileUtils.mkdir_p('db')

# Ensure the database and tables are set up
puts "Setting up the database..."
FileIndexer.new
puts "Database setup complete."
