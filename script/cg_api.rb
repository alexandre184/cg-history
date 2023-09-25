require "json"
require "uri"
require "net/http"


# body : []
URI_LANG = URI("https://www.codingame.com/services/ProgrammingLanguage/findAllIds")
# body : [userId] or [null]
URI_PROGRESS_ALL = URI("https://www.codingame.com/services/Puzzle/findAllMinimalProgress")
# body : [[ids..],userId,1] or [[ids..],null,1]
URI_PROGRESS = URI("https://www.codingame.com/services/Puzzle/findProgressByIds")
# body : [1,"CODEGOLF",{"keyword":"","active":false,"column":"","filter":""},null,true,"global"]
URI_LEADERBOARD_GLOBAL = URI('https://www.codingame.com/services/Leaderboards/getGlobalLeaderboard')
# body : [leaderboardId, nil, nil, {active: false, column: "", filter: ""}]
# body : [leaderboardId, nil, nil, {active: true, column: "LANGUAGE", filter: lang}]
URI_LEADERBOARD = URI('https://www.codingame.com/services/Leaderboards/getFilteredPuzzleLeaderboard')
# body : [userId]
URI_PLAYER = URI('https://www.codingame.com/services/CodinGamer/findCodinGamerPublicInformations')


def post(uri, params)
  res = Net::HTTP.post(uri, params.to_json, "Content-Type" => "application/json")
  (p uri, params; raise res.inspect) unless res.is_a?(Net::HTTPSuccess)
  yield res.body if block_given?
  JSON.parse(res.body)#, symbolize_names: true)
end

# for simplicity, assume all langs are available for all puzzle (which is not true!)
LANGS = ["all"].concat(post(URI_LANG, []))

HEADER_OPTIM = %w"score criteriaScore programmingLanguage creationTime codingamer.userId pseudo codingamer.countryId codingamer.avatar"
HEADER_MULTI = %w"league.divisionIndex score programmingLanguage creationTime agentId codingamer.userId pseudo codingamer.countryId codingamer.avatar"

