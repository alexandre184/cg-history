require "json"
require "csv"


###################################################################################################
# var section

TODAY = Time.now.utc

# In each multiplayer game, you gain CPs based on the following formula:
# (BASE * min(N/500, 1))^((N-C+1)/N)
# where BASE is a constant that depends on the game's category and represents the total number of CPs* you can get (by ranking first)
# N is the total number of players
# C is your rank
BASE_BY_TYPE = {"golf" => 200, "optim" => 2500, "multi" => 5000}
def points(type, n, c) = c ? ((BASE_BY_TYPE[type] * [n/("golf"==type ? 1.0 : 500.0), 1].min)**((n-c+1.0)/n)).ceil : "N/A"


# v1 < v2 is considered better
def            progress(v1, v2) = v1 ? v2 ? v1 < v2 ? "#{v2 - v1}⇗" : v1 > v2 ? "#{v1 - v2}⇘" : "-" : "Inf⇗" : "?"
def            delta_up(v1, v2) = v1 ? v2 ? v1 < v2 ? "-#{(v2 - v1).round(2)}" : v1 > v2 ? "+#{(v1 - v2).round(2)}" : "-" : "+Inf" : "?"
def          delta_down(v1, v2) = v1 ? v2 ? v1 > v2 ? "+#{(v1 - v2).round(2)}" : v1 < v2 ? "-#{(v2 - v1).round(2)}" : "-" : "-Inf" : "?"
def progress_color_down(v1, v2) = v1 ? v2.nil? || v1 < v2 ? "green" : v1 > v2 ? "red" : "" : ""
def   progress_color_up(v1, v2) = v1 ? v2.nil? || v1 > v2 ? "green" : v1 < v2 ? "red" : "" : ""
def             ordinalize(num) = num ? %w"th st nd rd"[num/10%10 == 1 || num%10 > 3 ? 0 : num%10] : ""

def layout(title, css, js, event_date = TODAY)
  <<~LAYOUT
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <title>CG History -- #{title}</title>
    #{css.map{|x| "<link rel=\"stylesheet\" href=\"/assets/#{x}.css\"/>"}.join("\n")}
    #{js.map{|x| "<script src=\"/assets/#{x}.js\" defer></script>"}.join("\n")}
    </head>
    <body>
      <header>
        <nav>
          <a href="https://www.codingame.com"><img loading="lazy" src="https://static.codingame.com/start/static/36d26855629fcefc237d0c7f32cdbc4b/1ca64/blobby-educated.png" /><div class="icon icon1"><div class="arrow"></div></div></a>
          <a href="/">CG-History</a>
          <a href="/events/#{event_date.strftime("%F")}.html">Events<div class="icon icon2"><div class="arrow"></div></div></a>
          <a href="/puzzles.html">Puzzles<div class="icon icon3"><div class="arrow"></div></div></a>
          <span id="github"></span>
          <a href="https://github.com/alexandre184/cg-history">Github<div class="icon icon4"><div class="arrow"></div></div></a>
        </nav>
      </header>
      <article>
        #{yield}
      </article>
      <footer>
        &copy; o.0 (#{TODAY.strftime("%Y")})
      </footer>
      <div id="snackbar"></div>
    </body>
  LAYOUT
end

def build_index_page
  layout("Home", %w"style intro", []) do
    <<~INDEX
      <h1>Welcome!</h1>
      <span class="intro"></span>
    INDEX
  end
end

def build_404_page
  layout("Home", %w"style", []) do
    <<~INDEX
      <h1>Congratulations, you reach the 404!</h1>
    INDEX
  end
end

def build_puzzle_page(puzzles)
  layout("Puzzles", %w"style", %w"script puzzle") do
    <<~INDEX
      <noscript>You need javascript here</noscript>
      <form id="puzzle-form">
        Diff between <input type="date" value="#{(TODAY - 86400).strftime("%F")}" name="date1" min="2019-09-09">
        and <input type="date" value="#{TODAY.strftime("%F")}" name="date2" min="2019-09-09">
        of <select name="puzzle">
        #{puzzles.group_by{|puzzle| puzzle["level"][/optim|multi/] || "golf" }
                 .sort.map{|type, puzzles| "<optgroup label=\"#{type}\">#{
                   puzzles.sort_by{|puzzle| puzzle["prettyId"].downcase }
                          .map{|puzzle| "<option value=\"#{puzzle["prettyId"]}\">#{puzzle["prettyId"]}</option>" }
                          .join("\n")
                  }</optgroup>" }
                 .join("\n")
          }
        </select>
        in <select name="lang">
        #{LANGS.map{|lang| "<option value=\"#{lang}\">#{lang}</option>" }.join("\n")}
        </select>
        lang
        <input type="submit" name="submit" value="ok">
      </form>
      <div id="puzzle-div"></div>
    INDEX
  end
end

def colspan(n, msg)
  <<~TR
    <tr class="sticky">
      <td colspan="#{n}">#{msg}</td>
    </tr>
  TR
end

def build_major_event_tr(row)
  new_score = row[:new]["criteriaScore"] || row[:new]["score"]
  new_old_score = row[:new_old]&.[]("criteriaScore") || row[:new_old]&.[]("score")
  old_new_score = row.dig(:old_new, "criteriaScore") || row.dig(:old_new, "score")
  old_score = row[:old]&.[]("criteriaScore") || row[:old]&.[]("score")
  <<~TR
    <tr>
      <td><a class="overflow" href="https://www.codingame.com/ide/puzzle/#{row[:prettyId]}" title="#{row[:prettyId]}">#{row[:prettyId]}</a></td>
      <td tooltip="#{t = Time.at(row[:new]["creationTime"].to_i / 1000).utc}">#{t.strftime("%F")}</td>
      <td>#{new_score} <span class="small #{row[:score_up][0] ? progress_color_up(new_score, new_old_score) : progress_color_down(new_score, new_old_score)}">(#{row[:score_up][0] ? delta_up(new_score, new_old_score) : delta_down(new_score, new_old_score)})</span></td>
      <td>#{row[:new]["programmingLanguage"]}</td>
      <td class="reverse"><a href="https://www.codingame.com/profile/#{row[:new]["codingamer.publicHandle"] || row[:new]["codingamer.userId"]}"><img loading="lazy" class="avatar" src="https://static.codingame.com/servlet/fileservlet?id=#{row[:new]["codingamer.avatar"]}&format=navigation_avatar" /><span>#{row[:new]["pseudo"] || "Unnamed Player"}</span><span class="country" title="#{row[:new]["codingamer.countryId"]}">#{row[:new]["codingamer.countryId"]&.tr("A-Z", "\u{1F1E6}-\u{1F1FF}")}</span></a></td>
      <td>-</td>
      <td><a href="https://www.codingame.com/profile/#{row[:old]["codingamer.userId"]}"><img loading="lazy" class="avatar" src="https://static.codingame.com/servlet/fileservlet?id=#{row[:old]["codingamer.avatar"]}&format=navigation_avatar" /><span>#{row[:old]["pseudo"] || "Unnamed Player"}</span><span class="country" title="#{row[:old]["codingamer.countryId"]}">#{row[:old]["codingamer.countryId"]&.tr("A-Z", "\u{1F1E6}-\u{1F1FF}")}</span></a></td>
      <td>#{row[:old]["programmingLanguage"]}</td>
      <td>#{old_new_score} <span class="small #{row[:score_up][0] ? progress_color_up(old_new_score, old_score) : progress_color_down(old_new_score, old_score)}">(#{row[:score_up][0] ? delta_up(old_new_score, old_score) : delta_down(old_new_score, old_score)})</span></td>
      <td tooltip="#{t = Time.at(row[:old]["creationTime"].to_i / 1000).utc}">#{t.strftime("%F")}</td>
    </tr>
  TR
end

def build_minor_event_tr(row)
  new_score = row[:new]["criteriaScore"] || row[:new]["score"]
  old_score = row[:old]["criteriaScore"] || row[:old]["score"]
  <<~TR
    <tr>
      <td><a class="overflow" href="https://www.codingame.com/ide/puzzle/#{row[:prettyId]}" title="#{row[:prettyId]}">#{row[:prettyId]}</a></td>
      <td tooltip="#{row[:new]["_rank_all_tie"]}#{ord = ordinalize(row[:new]["_rank_all_tie"])} (#{row[:new]["_rank_all"]}#{ordinalize(row[:new]["_rank_all"])}) / #{row[:count]}">#{row[:new]["_rank_all_tie"]}<sup>#{ord}</sup></td>
      <td class="#{progress_color_down(row[:new]["_rank_all_tie"], row[:old]["_rank_all_tie"])}">#{progress(row[:new]["_rank_all_tie"], row[:old]["_rank_all_tie"])}</td>
      <td tooltip="#{row[:new]["_rank_tie"]}#{ord = ordinalize(row[:new]["_rank_tie"])} (#{row[:new]["_rank"]}#{ordinalize(row[:new]["_rank"])}) / #{row[:filteredCount]}">#{row[:new]["_rank_tie"]}<sup>#{ord}</sup></td>
      <td class="#{progress_color_down(row[:new]["_rank_tie"], row[:old]["_rank_tie"])}">#{progress(row[:new]["_rank_tie"], row[:old]["_rank_tie"])}</td>
      <td><a href="https://www.codingame.com/profile/#{row[:new]["codingamer.publicHandle"] || row[:new]["codingamer.userId"]}"><img loading="lazy" class="avatar" src="https://static.codingame.com/servlet/fileservlet?id=#{row[:new]["codingamer.avatar"]}&format=navigation_avatar" /><span>#{row[:new]["pseudo"] || "Unnamed Player"}</span><span class="country" title="#{row[:new]["codingamer.countryId"]}">#{row[:new]["codingamer.countryId"]&.tr("A-Z", "\u{1F1E6}-\u{1F1FF}")}</span></a></td>
      <td>#{row[:new]["programmingLanguage"]}</td>
      <td>#{points(row[:type], row["golf" == row[:type] ? :filteredCount : :count], row[:new]["golf" == row[:type] ? "_rank_tie" : "_rank_all_tie"])}</td>
      <td>#{new_score.round(2)}</td>
      <td class="#{row[:score_up][0] ? progress_color_up(new_score, old_score) : progress_color_down(new_score, old_score)}">#{row[:score_up][0] ? delta_up(new_score, old_score) : delta_down(new_score, old_score)}</td>
      <td tooltip="#{t = Time.at(row[:new]["creationTime"].to_i / 1000).utc}">#{t.strftime("%F")}</td>
    </tr>
  TR
end

def build_event_page(major_events, minor_events, event_date = TODAY)
  major_events.sort_by!{|e| [e[:type], e[:prettyId].downcase, e[:lang].downcase] }
  minor_events.sort_by!{|e| [e[:type], e[:prettyId].downcase, e[:lang].downcase, e[:new]["_rank"]] }
  outstanding_events, major_events = major_events.partition{|e| "all" == e[:lang] }
  page = layout("Events of #{event_date.strftime("%F")}", %w"style", %w"script") do
    <<~PAGE
      <h1>Events of #{event_date.strftime("%F")}</h1>
      <div class="solve">
      <span>#{outstanding_events.size} outstanding events (1st overall) and #{major_events.size} major events (1st lang) and #{minor_events.size} minor events (personal best or not!)</span>
        <a href="/events/#{(event_date - 86400).strftime("%F")}.html">prev day</a>
        <a href="/events/#{(event_date + 86400).strftime("%F")}.html">next day</a>
      </div><hr>
      #{
      <<~DIV if outstanding_events.any?
        <div>
          <h3>Outstanding events</h3>
          <table class="sticky">
            <thead>
              <tr><th>Puzzle</th><th>Time</th><th>Score</th><th>Lang</th><th>Player</th><th>vs</th><th>Player</th><th>Lang</th><th>Score</th><th>Time</th></tr>
            </thead>
            <tbody>
              #{headers = {}; outstanding_events.reduce(""){|acc, row| headers[row[:type]] ||= acc << colspan(10, row[:type]); acc << build_major_event_tr(row) }}
            </tbody>
          </table>
        </div>
      DIV
      }
      #{
      <<~DIV if major_events.any?
        <div>
          <h3>Major events</h3>
          <table class="sticky">
            <thead>
              <tr><th>Puzzle</th><th>Time</th><th>Score</th><th>Lang</th><th>Player</th><th>vs</th><th>Player</th><th>Lang</th><th>Score</th><th>Time</th></tr>
            </thead>
            <tbody>
              #{headers = {}; major_events.reduce(""){|acc, row| headers[row[:type]] ||= acc << colspan(10, row[:type]); acc << build_major_event_tr(row) }}
            </tbody>
          </table>
        </div>
      DIV
      }
      #{
      <<~DIV if minor_events.any?
        <div>
          <h3>Minor events</h3>
          <table class="sticky">
            <thead>
              <tr><th>Puzzle</th><th>Global</th><th>Progress</th><th>Rank</th><th>Progress</th><th>Player</th><th>Lang</th><th>Points</th><th>Score</th><th>Delta</th><th>Time</th></tr>
            </thead>
            <tbody>
              #{headers = {}; minor_events.reduce(""){|acc, row| headers[row[:type]] ||= acc << colspan(11, row[:type]); acc << build_minor_event_tr(row) }}
            </tbody>
          </table>
        </div>
      DIV
      }
    PAGE
  end
end


