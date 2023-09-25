require "csv"
require "json"
require "fileutils"

require_relative "../cg_api"
require_relative "../page_build"
require_relative "../event_build"

# possible to get history of running filter-branch?
# use a tmp directory instead
root_folder = ARGV.shift
tmp_dir = "#{root_folder}/script/history"
tmp_puzzle_dir = "#{tmp_dir}/puzzle"

if File.directory?(tmp_puzzle_dir)
  major_events = []
  minor_events = []
  Dir::glob("puzzle/*/*").each do |x|
    _, type, prettyId = x.split("/")
    maj, min, all = events({"_type" => type, "prettyId" => prettyId, }, "#{tmp_dir}/")
    major_events.concat(maj)
    minor_events.concat(min)
    minor_events.concat(all) if "golf" != type
  end
  time = Time.at(ENV["GIT_AUTHOR_DATE"][/\d+/].to_i).utc
  IO.write("#{root_folder}/docs/events/#{time.strftime("%F")}.html", build_event_page(major_events, minor_events, time))
end

if File.directory?("puzzle")
  FileUtils.copy_entry("puzzle", tmp_puzzle_dir, preserve: true, remove_destination: true)
end
