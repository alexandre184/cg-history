

function snackbar(text) {
  const x = document.getElementById("snackbar")
  clearTimeout(x["data-timeout"])
  x.classList.remove("show")
  // this line is useful : Trigger a reflow, flushing the CSS changes to cancel the animation
  x.offsetHeight
  x.innerText = text
  x.classList.add("show")
  x["data-timeout"] = setTimeout(() => {
    x.classList.remove("show")
    x.removeAttribute("data-timeout")
  }, 5000)
}

// wow, without the semicolon there is an exception at line 21: script.js:19 Uncaught TypeError: window.addEventListener(...) is not a function
// => limit of ASI: Automatic Semicolon Insertion
window.addEventListener("error", e => snackbar('Oh no, an exception... Get the log, go to github, and blame the autor of this site ;)'));

(function() {

const handler = e => {
  const a = e.target.closest("a")
  if (a) {
    const [, id] = a.href.split('https://www.codingame.com/profile/')
    // assume publicHandle contains at least one \D.
    // if not, fallback to CG response !
    if (/\d+/.test(id)) {
      // edit, CG does not allow cors :(
      //fetch("https://www.codingame.com/services/CodinGamer/findCodinGamerPublicInformations",{body: JSON.stringify([id]),method: "POST",headers: {"Content-Type": "application/json"}})
      e.preventDefault()
      snackbar(`CG does not allows CORS to retrieve handle from id (${id})`)
    }
  }
}
document.addEventListener('click', handler)
document.addEventListener('auxclick', handler)

})()