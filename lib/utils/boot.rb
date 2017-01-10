# encoding: utf-8
# Boot Assitant Methods
module Utils
  # Boot Assitant Methods
  module Boot
    def recursion_require(dir_path, regexp, base_path = ENV['APP_ROOT_PATH'], sort_rules = [])
      dir_path_on_base = format('%s/%s', base_path, dir_path)
      partition = Dir.entries(dir_path_on_base)
                     .reject { |dir_name| %w(. ..).include?(dir_name) }
                     .partition { |dir_name| File.file?(%(#{dir_path_on_base}/#{dir_name})) }
      temp_files, temp_dirs = *partition

      unless sort_rules.empty?
        temp_files = sort_by_rules(temp_files, sort_rules)
      end
      temp_files.each do |dir_name|
        file_path = %(#{dir_path_on_base}/#{dir_name})
        warn_info = %(warning not match #{regexp.inspect} - #{file_path})
        dir_name.scan(regexp).empty? ? (warn warn_info) : (require file_path)
      end unless temp_files.empty?

      temp_dirs.each do |dir_name|
        recursion_require(%(#{dir_path}/#{dir_name}), regexp, base_path, sort_rules)
      end unless temp_dirs.empty?
    end

    def sort_by_rules(array, rules)
      flatten_array = rules.inject([]) do |tmp, rule|
        tmp.push(array.grep(rule))
      end.flatten!
      flatten_array.push(array - flatten_array).flatten!
    end
  end
end
