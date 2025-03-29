require "csv"
require "json"
require "fileutils"

require_relative "cg_api"

CSV::Converters[:numeric_inf] = proc do |x|
  '-inf' == x ? -Float::INFINITY : 'inf' == x ? Float::INFINITY : x
end

def events(puzzle, old_prefix = "")
  major_events = []
  minor_events = []
  leaderboardId = puzzle["puzzleLeaderboardId"]
  prettyId = puzzle["prettyId"]
  type = puzzle["_type"]
  header = "multi" == type ? HEADER_MULTI : HEADER_OPTIM
  folder = "puzzle/#{type}/#{prettyId}"
  FileUtils.mkdir_p folder
  FileUtils.mkdir_p "tmp/#{folder}" if leaderboardId
  event_by_idlang = {}
  all = []
  # hack ? definitely yes! One caveat if all leaderboard are tied
  score_up = []
  LANGS.each do |lang|
    file = "#{folder}/#{lang}.csv"
    # Do not use header_converters: :symbol, because it removes some character and transform to downcase
    leaderboard_old = CSV.parse(File.open("#{old_prefix}#{file}"), headers: true, converters: [:numeric, :numeric_inf]) rescue []
    if leaderboardId
      # Get sometimes a 502 Bad Gateway... so keep file until succeed
      begin
        leaderboard = JSON.parse(IO.read("tmp/#{folder}/#{lang}.json"))#, symbolize_names: true)
      rescue => exception
        begin
          leaderboard = post(URI_LEADERBOARD, [leaderboardId, nil, nil, {active: true, column: "LANGUAGE", filter: lang}])
          if leaderboard.nil? # skip also null leaderboard that can now occur
            p [:null, leaderboardId, lang]
            next
          end
        rescue Net::ReadTimeout
          # can now occur on big leaderboard, aka mad-pod-racing
          # skip it
          p [:timeout, leaderboardId, lang]
          next
        end
        IO.write("tmp/#{folder}/#{lang}.json", leaderboard.to_json)
      end
      count, filteredCount = leaderboard.values_at("count", "filteredCount")
      leaderboard = leaderboard["users"].map{|u| header.to_h{|h| [h, u.dig(*h.split("."))] }.merge!("codingamer.publicHandle" => u.dig("codingamer", "publicHandle")) }
    else
      leaderboard = CSV.parse(File.open(file), headers: true, converters: [:numeric, :numeric_inf]) rescue next
      filteredCount = leaderboard.headers[-1][/count=\K\d+/].to_i
      count = "all" == lang ? filteredCount : File.open("#{folder}/all.csv"){|f| f.gets }[/count=\K\d+/].to_i
    end
    # old preprocessing
    rank_tie = score_prev = nil
    old_by_idlang = leaderboard_old.each.with_index(1).to_h do |user, rank|
      if score_prev != (score_next = [user["league.divisionIndex"] || user["score"], user["criteriaScore"] || user["score"]])
        rank_tie = rank
        lp, sp = score_prev
        ln, sn = score_next
        # sn can be nil if waiting for submission (ex: spring-challenge-2022)
        score_up[0] = sp > sn if sp && sn && lp == ln && sp != sn
        score_prev = score_next
      end
      user["_rank"] = rank
      user["_rank_tie"] = rank_tie
      [[user["codingamer.userId"], "golf" == type && user["programmingLanguage"]], user]
    end
    # personnal best
    rank_tie = score_prev = nil
    new_by_idlang = leaderboard.each.with_index(1).to_h do |user, rank|
      old = old_by_idlang[[user["codingamer.userId"], "golf" == type && user["programmingLanguage"]]] || {}
      if score_prev != (score_next = [user["league.divisionIndex"] || user["score"], user["criteriaScore"] || user["score"]])
        rank_tie = rank
        lp, sp = score_prev
        ln, sn = score_next
        # sn can be nil if waiting for submission (ex: spring-challenge-2022)
        score_up[0] = sp > sn if sp && sn && lp == ln && sp != sn
        score_prev = score_next
      end
      user["_rank"] = rank
      user["_rank_tie"] = rank_tie
      # not convinced by this test!
      if user["criteriaScore"] != old["criteriaScore"] || rank_tie != old["_rank_tie"] && (rank_tie == 1 || old["creationTime"] && user["creationTime"] != old["creationTime"])
        event = {type: type, prettyId: prettyId, lang: lang, score_up: score_up, count: count, filteredCount: filteredCount, new: user, old: old}
        "all" == lang ? all << event : minor_events << event_by_idlang[[user["codingamer.userId"], lang]] = event
      end
      [[user["codingamer.userId"], "golf" == type && user["programmingLanguage"]], user]
    end
    # major and outstanding events
    first_old = leaderboard_old.first || {}
    first_new = leaderboard.first || {}
    # don't check multi score change! Or maybe only if submission time / league change? first_new["score"] != first_old["score"]
    if first_new["criteriaScore"] != first_old["criteriaScore"] || first_new["codingamer.userId"] != first_old["codingamer.userId"]
      # get second if already first player to get more useful info
      first_old = leaderboard_old[1] || {} if first_new["codingamer.userId"] == first_old["codingamer.userId"] && first_new["programmingLanguage"] == first_old["programmingLanguage"]
      major_events << {type: type, prettyId: prettyId, lang: lang, score_up: score_up, new: first_new, new_old: old_by_idlang[[first_new["codingamer.userId"], "golf" == type && first_new["programmingLanguage"]]], old: first_old, old_new: new_by_idlang[[first_old["codingamer.userId"], "golf" == type && first_old["programmingLanguage"]]]}
    end
    IO.write(file, (header + ["##{type}|count=#{filteredCount}|time=#{TODAY.strftime("%FT%T")}"]).to_csv + leaderboard.map{|u| header.map{|h| u[h] }.push(nil).to_csv }.join) if leaderboardId
  end
  all.each do |event|
    event2 = event_by_idlang[[event[:new]["codingamer.userId"], event[:new]["programmingLanguage"]]]
    # happen if a user enter the global leaderboard
    next unless event2
    event2[:new]["_rank_all"] = event[:new]["_rank"]
    event2[:new]["_rank_all_tie"] = event[:new]["_rank_tie"]
    event2[:old]["_rank_all"] = event[:old]["_rank"]
    event2[:old]["_rank_all_tie"] = event[:old]["_rank_tie"]
  end
  return major_events, minor_events, all
end
