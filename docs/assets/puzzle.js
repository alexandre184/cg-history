
(function() {

////////////////////
// github request //
////////////////////

// first idea was to change the color of the api limit. emoji is way more fun !
function percentageToHsl(percentage, hue0, hue1) {
  const hue = percentage * (hue1 - hue0) + hue0;
  return `hsl(${hue}, 100%, 50%)`;
}

function updateGithubLimit(req) {
  // TODO, avoid error log on chrome
  const remain = req.getResponseHeader('x-ratelimit-remaining')
  if (remain) {
    const limit = req.getResponseHeader('x-ratelimit-limit')
    const reset = req.getResponseHeader('x-ratelimit-reset')
    const github = document.getElementById('github')
    github.innerText = `API limit: ${['😵','😱','🙁','😐','🙂','😁'][remain/limit*5+.99|0]} ${remain} / ${limit} (${new Date(reset * 1000).toLocaleString()})`
  }
}

function githubReqCommit(date, per_page) {
  // do not have headers on all browser :(
  // const req = await fetch(`https://api.github.com/repos/alexandre184/cg-history/commits?since=${date1}T00:00:00Z&until=${date1}T23:59:59Z`)
  // console.log(...req.headers)
  const req = new XMLHttpRequest()
  req.open('GET', `https://api.github.com/repos/alexandre184/cg-history/commits?per_page=${per_page}&until=${date}T23:59:59Z`, false)
  req.send()
  updateGithubLimit(req)
  if (req.status != 200) throw new Error('The status of the last request is not 200')

  return JSON.parse(req.responseText)
}

function githubReqPuzzle(sha, type, lang, puzzle) {
  const req = new XMLHttpRequest()
  const url = `https://raw.githubusercontent.com/alexandre184/cg-history/${sha}/puzzle/${type}/${encodeURIComponent(puzzle)}/${encodeURIComponent(lang)}.csv`
  req.open('GET', url, false)
  req.send()
  // just in case
  updateGithubLimit(req)
  if (req.status != 200 && req.status != 404) throw new Error('The status of the last request is not 200 or 404')

  let [header, ...body] = req.responseText.trim().split('\n').map(x => x.split(','))
  body = body.map(row => row.reduce((h, val, i) => (h[header[i]] = val, h), {}))

  return {url, status: req.status, csv: {count: header.at(-1)?.match(/\d+/)?.[0], header, body}}
}

function digGithubHistory(date1, date2, type, lang, puzzle) {
  const date_min = date1 < date2 ? date1 : date2
  const json = githubReqCommit(date1 < date2 ? date2 : date1, 100)
  const commits = json.sort((c1, c2) => new Date(c2.commit.committer.date) - new Date(c1.commit.committer.date))
  let c1, c2 = commits[0]
  // avoid request if possible
  // c2 nil if to old
  if (c2) {
    c1 = commits.find(commit => date_min >= commit.commit.committer.date.substring(0,10))
    // no choice, another request
    if (!c1) c1 = githubReqCommit(date_min, 1)[0]
    if (date1 > date2) [c1, c2] = [c2, c1]
  }

  return githubReqPuzzles(c1, date1, c2, date2, type, lang, puzzle)
}

function githubReqPuzzles(c1, date1, c2, date2, type, lang, puzzle) {
  const p1 = c1 ? githubReqPuzzle(c1.sha, type, lang, puzzle) : {status: 'commit not found', csv: {header: [], body: []}}
  const p2 = c2 ? githubReqPuzzle(c2.sha, type, lang, puzzle) : {status: 'commit not found', csv: {header: [], body: []}}

  return {date1, date2, type, lang, puzzle, p1: {commit: c1, puzzle: p1}, p2: {commit: c2, puzzle: p2}}
}


////////
// UI //
////////

function spanDate(data, px, datex) {
  const date = px.commit?.commit?.committer?.date || '???'
  return `<span tooltip>${date.substring(0, 10)}<span class="tooltip">status: ${px.puzzle.status}<br>date: ${date} (${datex})<br>raw: <a${px.puzzle.url ? ` href="${px.puzzle.url}"` : ''}>${data.lang}.csv</a></span></span>`
}


function build_leaderboard_puzzle(data) {
return `
  <input id="request-data" type="hidden" value="type=${data.type}&c1date=${data.p1.commit?.commit?.committer?.date || '???'}&c1sha=${data.p1.commit?.sha}&c2date=${data.p2.commit?.commit?.committer?.date || '???'}&c2sha=${data.p2.commit?.sha}">
  <h1>Diff between ${spanDate(data, data.p1, data.date1)} and ${spanDate(data, data.p2, data.date2)}</h1>
  <div class="solve">
    <span>${data.puzzle} in ${data.lang} lang</span>
    <a href="https://www.codingame.com/ide/puzzle/${data.puzzle}">Solve</a>
  </div><hr>
  <main>
    <nav>
      <details open>
        <summary>Lang</summary>
        ${[...document.querySelectorAll('select[name="lang"] option')].map(opt => `<a${opt.value == data.lang ? '' : ` href="../puzzles.html?date1=${data.date1}&date2=${data.date2}&puzzle=${encodeURIComponent(data.puzzle)}&lang=${encodeURIComponent(opt.value)}"`}>${opt.value}</a>`).join('\n')}
      </details>
      ${[...document.querySelectorAll('select[name="puzzle"] optgroup')].map(optg => `<details><summary>${optg.label}</summary>${[...document.querySelectorAll(`select[name="puzzle"] optgroup[label="${optg.label}"] option`)].map(opt => `<a class="overflow"${opt.value == data.puzzle ? '' : ` href="../puzzles.html?date1=${data.date1}&date2=${data.date2}&puzzle=${encodeURIComponent(opt.value)}&lang=${encodeURIComponent(data.lang)}"`}>${opt.value}</a>`).join('\n') }</details>`).join('\n')}
    </nav>
    <table class="sticky">
      <thead>
        <tr><th>Rank</th><th>Progress</th><th>Player</th><th>Lang</th><th>Points</th><th>Score</th><th>Delta</th><th>Time</th></tr>
      </thead>
      <tbody>
        ${buildTable(data)}
      </tbody>
    </table>
  </main>
`
}

function buildTable(data) {
  let trs = ''
  let rank_tie, score_prev = [], score_next, score_up
  const old_by_idlang = new Map();
  data.p1.puzzle.csv.body.forEach((user, rank) => {
    if (score_prev + '' != (score_next = [user["league.divisionIndex"] || user["score"], user["criteriaScore"] || user["score"]])) {
      rank_tie = rank + 1
      const [lp, sp] = score_prev
      const [ln, sn] = score_next
      // sn can be nil if waiting for submission (ex: spring-challenge-2022)
      if (sp && sn && lp == ln) score_up = sp > sn
      score_prev = score_next
    }
    user["_rank"] = rank + 1
    user["_rank_tie"] = rank_tie
    old_by_idlang[[user["codingamer.userId"], "golf" == data.type && user["programmingLanguage"]]] = user
  })
  rank_tie = score_prev = []
  data.p2.puzzle.csv.body.forEach((user, rank) => {
    old = old_by_idlang[[user['codingamer.userId'], "golf" == data.type && user['programmingLanguage']]] || {}
    if (score_prev + '' != (score_next = [user['league.divisionIndex'] || user['score'], user['criteriaScore'] || user['score']])) {
      rank_tie = rank + 1
      const [lp, sp] = score_prev
      const [ln, sn] = score_next
      // sn can be nil if waiting for submission (ex: spring-challenge-2022)
      if (sp && sn && lp == ln) score_up = sp > sn
      score_prev = score_next
    }
    user['_rank'] = rank + 1
    user['_rank_tie'] = rank_tie
    trs += build_tr({data, score_up, new: user, old})
  })
  return trs || '<tr><td>Hoho 😅, no data !</td></tr>'
}


function build_tr(row) {
  const new_score = row.new['criteriaScore'] || row.new['score']
  const old_score = row.old['criteriaScore'] || row.old['score']
  const ord = ordinalize(row.new['_rank_tie'])
  const date = new Date(+row.new['creationTime'] || 0).toISOString()
return `
  <tr>
    <td tooltip="${row.new['_rank_tie']}${ord} (${row.new['_rank']}${ordinalize(row.new['_rank'])}) / ${row.data.p1.puzzle.csv.count}">${row.new['_rank_tie']}<sup>${ord}</sup></td>
    <td class="${progress_color_down(row.new['_rank_tie'], row.old['_rank_tie'])}">${progress(row.new['_rank_tie'], row.old['_rank_tie'])}</td>
    <td><a href="https://www.codingame.com/profile/${row.new['codingamer.userId']}"><img loading="lazy" class="avatar" src="https://static.codingame.com/servlet/fileservlet?id=${row.new['codingamer.avatar'] || ''}&format=navigation_avatar" /><span>${row.new['pseudo'] || "Unnamed Player"}</span><span class="country" title="${row.new['codingamer.countryId'] || 'N/A'}">${row.new['codingamer.countryId']?.replace(/./g, c => String.fromCodePoint(0x1f1a5 + c.charCodeAt())) || ''}</span></a></td>
    <td>${row.new['programmingLanguage']}</td>
    <td>${'golf' != row.data.type ^ 'all' == row.data.lang ? 'N/A' : points(row.data.type, row.data.p1.puzzle.csv.count, row.new['_rank_tie'])}</td>
    <td>${new_score}</td>
    <td class="${row.score_up ? progress_color_up(new_score, old_score) : progress_color_down(new_score, old_score)}">${row.score_up ? delta_up(new_score, old_score) : delta_down(new_score, old_score)}</td>
    <td tooltip="${date}">${date.substring(0, 10)}</td>
  </tr>
`
}

// In each multiplayer game, you gain CPs based on the following formula:
// (BASE * min(N/500, 1))^((N-C+1)/N)
// where BASE is a constant that depends on the game's category and represents the total number of CPs* you can get (by ranking first)
// N is the total number of players
// C is your rank
const BASE_BY_TYPE = {golf: 200, optim: 2500, multi: 5000}
function          points(type, n, c) { return Math.ceil((BASE_BY_TYPE[type] * Math.min(n/('golf'==type ? 1 : 500), 1))**((n-c+1)/n)) }
function             ordinalize(num) { return num ? ['th', 'st', 'nd', 'rd'][(num/10|0)%10 == 1 || num%10 > 3 ? 0 : num%10] : "" }
// v1 < v2 is considered better
function            progress(v1, v2) { return v1 ? v2 ? v1 < v2 ? `${v2 - v1}⇗` : v1 > v2 ? `${v1 - v2}⇘` : '-' : 'Inf⇗' : '?' }
function            delta_up(v1, v2) { return v1 ? v2 ? v1 < v2 ? `-${(v2 - v1).toFixed(2)}` : v1 > v2 ? `+${(v1 - v2).toFixed(2)}` : '-' : '+Inf' : '?' }
function          delta_down(v1, v2) { return v1 ? v2 ? v1 > v2 ? `+${(v1 - v2).toFixed(2)}` : v1 < v2 ? `-${(v2 - v1).toFixed(2)}` : '-' : '-Inf' : '?' }
function progress_color_down(v1, v2) { return v1 ? !v2 || v1 < v2 ? 'green' : v1 > v2 ? 'red' : '' : '' }
function   progress_color_up(v1, v2) { return v1 ? !v2 || v1 > v2 ? 'green' : v1 < v2 ? 'red' : '' : '' }


////////////////////////
// form + url handler //
////////////////////////

document.getElementById('puzzle-form').addEventListener('submit', e => {
  try {
    console.log(e)
    e.preventDefault()
    const form = new FormData(e.target)
    console.log(form.get('date1'),form.get('date2'),form.get('puzzle'),form.get('lang'))
    const data = digGithubHistory(form.get('date1'), form.get('date2'), document.querySelector('select[name="puzzle"] option:checked').parentElement.label, form.get('lang'), form.get('puzzle'))
    document.getElementById('puzzle-div').innerHTML = build_leaderboard_puzzle(data)
    history.replaceState(null, '', `/puzzles.html?${new URLSearchParams(form)}`)
    console.log(data)
  } catch (ex) {
    snackbar('An error occured. See log for details')
    throw ex
  }
})

const handler = e => {
  const a = e.target.closest("a")
  if (a) {
    let [, params] = a.href.split('/puzzles.html?')
    if (params) {
      e.preventDefault()
      params = new URLSearchParams(params)
      const params_data = new URLSearchParams(document.getElementById('request-data').value)
      const c1 = {sha: params_data.get('c1sha'), commit: {committer: {date: params_data.get('c1date')}}}
      const c2 = {sha: params_data.get('c2sha'), commit: {committer: {date: params_data.get('c2date')}}}
      const data = githubReqPuzzles(c1, params.get('date1'), c2, params.get('date2'), params_data.get('type'), params.get('lang'), params.get('puzzle'))
      document.getElementById('puzzle-div').innerHTML = build_leaderboard_puzzle(data)
      history.replaceState(null, '', a.href)
    }
  }
}
document.addEventListener('click', handler)
//document.addEventListener('auxclick', handler)

// simulate a query when loading with params
let [, params] = document.location.href.split('/puzzles.html?')
if (params) {
  params = new URLSearchParams(params)
  const data = digGithubHistory(params.get('date1'), params.get('date2'), document.querySelector(`select[name="puzzle"] option[value="${params.get('puzzle')}"]`).parentElement.label, params.get('lang'), params.get('puzzle'))
  document.getElementById('puzzle-div').innerHTML = build_leaderboard_puzzle(data)
}

})()