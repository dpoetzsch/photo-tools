require "set"
require "yaml"

def merge_dbs(db_files)
  db = {}

  db_files.each do |db_file|
    yaml = YAML.load(File.read(db_file))

    # mark origins
    yaml.each do |k,v|
      yaml[k]["origin_hashdb"] = db_file
    end

    db = db.merge(yaml)
  end

  db
end

def cleanup_db(db)
  db.each do |k,v|
    db.delete(k) unless File.exist? k
  end
end

# Print a number of duplicates s.t. the resulting output will
# be a valid YAML
def print_dups(id, duplicates)
  o = { "Duplicates #{id}" => duplicates }
  puts o.to_yaml(options = { line_width: -1 }).sub("---\n", "")
  puts
end

def remove_false_positives(db, duplicates)
  # each element is considered equal to each other element
  # => array of all pairs
  equalities = duplicates.combination(2).map { |e| e.to_set }

  # Now, remove all equalities that are known to be unequal
  duplicates.each do |d|
    uqs = db[d]["unequal_to"] || {}

    # filter out all outdated entries
    uqs = uqs.find_all { |k, v| v["mtime"] == File.mtime(k).to_f }

    equalities -= uqs.map { |e| Set.new [d, e[0]] }
  end

  # Finally rebuild the duplicate sets
  start = []
  result = equalities
  while result != start
    start = result.clone
  
    i = -1
    while (i += 1) < result.length
      next if result[i].nil?

      (i+1).upto(result.length - 1).each do |j|
        if !result[j].nil? && !result[i].intersection(result[j]).empty?
          result[i] += result[j]
          result[j] = nil
        end
      end
    end

    result = result.find_all { |e| !e.nil? }
  end

  result.map { |e| e.to_a }
end
