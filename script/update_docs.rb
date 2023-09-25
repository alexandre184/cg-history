require "json"
require "csv"
require "fileutils"

require_relative "cg_api"
require_relative "page_build"
require_relative "event_build"

major_events = []
minor_events = []

levels = %w"codegolf-easy codegolf-medium codegolf-hard codegolf-expert optim multi"

level_skipped = {}
puzzles = post(URI_PROGRESS_ALL, [nil])
puzzles_id = puzzles.filter_map{|puzzle| puzzle["id"] if levels.include?(puzzle["level"]) || level_skipped[puzzle["level"]] = nil }
puts "Skip puzzles with level : #{level_skipped.keys.join(', ')}"


puzzles = post(URI_PROGRESS, [puzzles_id, nil, 1])
puzzles.each.with_index(1) do |puzzle, nb|
  p [nb, puzzles.size, puzzle["prettyId"]]
  puzzle["_type"] = puzzle["level"][/optim|multi/] || "golf"
  maj, min = events(puzzle)
  major_events.concat(maj)
  minor_events.concat(min)
end

IO.write("docs/events/#{TODAY.strftime("%F")}.html", build_event_page(major_events, minor_events))
IO.write("docs/index.html", build_index_page)
IO.write("docs/puzzles.html", build_puzzle_page(puzzles))
IO.write("docs/404.html", build_404_page)
