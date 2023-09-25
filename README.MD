# cg-history

## History / How it works

The aim of that thing was at the beggining to track major leaderboard changes. But you know, after writing some code, '*hey, I have more info, just track everything!*'

Before that I was using history of dbdr repo codingame-leaderboards, but it's unfortunately no more active.

The first idea was to use github as a server to track, save and generate once a day changes in leaderboards, and github-pages as a web-server to serve those generated pages. The job was almost done when I realized that in the worst case a page is ~500ko, and there is 27 langs, and ~100 puzzles => > 1go. The github-pages size limit would be reach in less than one day of history :).

Need to add a layer to that stack. The diff will no more be generated statically each day on github, but on demand by digging github history through javascript. That change make possible to compare specific versions, cool. Now the github limit is on your side by using the api :p.

I stole the history of dbdr. Just rewrote the entire history to match my need, which was quite interesting. You may have a look at [/script/history/rewrite.sh](rewrite.sh)

For my use it's already way more that I wanted. But if you think of another usecase, feel free to contribute :). I leave some TODO that I may or may not do!

## Run locally

```bash
# site available at localhost:8000
python3 -m http.server --directory site

sh script/udpate_cg_history.sh
```

## Caveat

It's certainly no bug free but there is at least on caveat that is not easy to handle. For one puzzle, 1 + nb lang requests is produced to get all leaderboards. Because a score can be updated between requests, some data could be incacurrate between global and lang leaderboard. Or even from one day to another.

For optim and golf: The submission date of old (<= 2023-02-07) entries is approximate, as is the score before 2021-06-23<br>
For multi: No submission date before 2023-02-07

## TODO
- [ ] Retrieve player handle from id. CORS problem with CG. don't want to store handle.
- [ ] Add league for multi + fix delta when league change
- [ ] Add clash leaderboard
- [ ] Show completion for golf and optim
- [ ] Improve/fix UX/UI (like the sticky stacking positionning that behave differently on browser)
- [x] Compare specific versions with js
- [ ] Compare specific versions: handle before 2023-02-07 better
- [x] optimize API limit
- [ ] Add a user diff page (this one could actually be cool!)
- [x] dbdr history
- [x] generate old events?
- [ ] CRON job
- [ ] fix cp script
- [ ] ...

## Useful links

- https://docs.github.com/en/rest
- https://git-scm.com/docs/git-filter-branch
- https://developer.mozilla.org/en-US/docs/Web
- https://github.com/brandonmcconnell/typed.css
- https://github.com/dbdr/codingame-leaderboards


