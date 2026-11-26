.pragma library
.import "Words.js" as W

// Word suggestions and autocorrect for theOne (English).
// Words.js holds ~47k words ordered by how common they are; the rank stands in for
// frequency (Zipf). On top of it sits what the user has taught the keyboard: words
// that are not in the list, and which word tends to follow which.

var ready = false
var words = []                  // ranked, lower case
var rank = Object.create(null)  // word -> rank
var hidden = Object.create(null)
var bareOf = []                 // rank -> word without apostrophes
var foldMap = Object.create(null) // word without apostrophes or accents -> [rank, ...]
var sorted = []                 // alphabetical, for prefix lookups

// Learned data: w = word counts, f = display forms ("iPhone"), b = bigrams {prev: {next: n}}.
var user = { w: {}, f: {}, b: {} }
var dirty = false

var PROPER = {
    "i": "I", "monday": "Monday", "tuesday": "Tuesday", "wednesday": "Wednesday",
    "thursday": "Thursday", "friday": "Friday", "saturday": "Saturday", "sunday": "Sunday",
    "january": "January", "february": "February", "april": "April", "june": "June",
    "july": "July", "september": "September", "october": "October", "november": "November",
    "december": "December", "english": "English", "christmas": "Christmas"
}

function fold(w) {
    var out = ""
    for (var i = 0; i < w.length; ++i) {
        var c = w[i]
        if (c !== "'")
            out += BASE[c] || c
    }
    return out
}

function init() {
    if (ready)
        return
    words = W.WORDS.split(" ")
    for (var i = 0; i < words.length; ++i) {
        var w = words[i]
        rank[w] = i
        bareOf.push(w.replace(/'/g, ""))
        var f = fold(w)
        if (foldMap[f])
            foldMap[f].push(i)
        else
            foldMap[f] = [i]
    }
    var h = W.HIDDEN.split(" ")
    for (var j = 0; j < h.length; ++j)
        if (h[j] !== "")
            hidden[h[j]] = true
    sorted = W.SORTED.split(" ")
    ready = true
}

// --- learned words ---------------------------------------------------------------------

function load(json) {
    try {
        var d = JSON.parse(json)
        user = { w: d.w || {}, f: d.f || {}, b: d.b || {} }
    } catch (e) {
        user = { w: {}, f: {}, b: {} }
    }
}

function dump() {
    prune()
    dirty = false
    return JSON.stringify(user)
}

function prune() {
    var keys = Object.keys(user.w)
    if (keys.length > 4000)
        for (var i = 0; i < keys.length; ++i)
            if (user.w[keys[i]] < 2) {
                delete user.w[keys[i]]
                delete user.f[keys[i]]
            }
    var prevs = Object.keys(user.b)
    if (prevs.length > 3000)
        for (var j = 0; j < prevs.length; ++j) {
            var nexts = user.b[prevs[j]], total = 0
            for (var n in nexts) total += nexts[n]
            if (total < 2) delete user.b[prevs[j]]
        }
}

function userCount(lw) {
    return user.w.hasOwnProperty(lw) ? user.w[lw] : 0
}

// strong: the user insisted on this exact word (tapped it, or undid a correction).
function learn(word, prev, strong) {
    init()
    var lw = word.toLowerCase()
    if (lw === "" || /[0-9]/.test(lw))
        return
    var c = userCount(lw) + 1
    if (strong && c < 2)
        c = 2
    user.w[lw] = c
    if (/[A-Z]/.test(word.slice(1)) || (strong && word !== lw && !(lw in rank)))
        user.f[lw] = word
    if (prev) {
        var lp = prev.toLowerCase()
        if (!user.b.hasOwnProperty(lp))
            user.b[lp] = {}
        user.b[lp][lw] = (user.b[lp][lw] || 0) + 1
    }
    dirty = true
}

function isKnown(lw) {
    init()
    return (lw in rank) || (lw in hidden) || userCount(lw) >= 2
}

// --- scoring ---------------------------------------------------------------------------

function logFreq(lw) {
    var s = (lw in rank) ? -Math.log(rank[lw] + 20) : -Math.log(60000)
    var u = userCount(lw)
    if (u > 0)
        s = Math.max(s, -Math.log(2000)) + Math.log(1 + u)
    return s
}

// Keyboard geometry for "fat finger" costs.
var KEYPOS = (function () {
    var rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"], off = [0, 0.5, 1.5], p = {}
    for (var r = 0; r < rows.length; ++r)
        for (var i = 0; i < rows[r].length; ++i)
            p[rows[r][i]] = { x: i + off[r], y: r }
    return p
})()

var BASE = (function () {
    var acc = { a: "àáâäæãåā", c: "çćč", e: "èéêëēėę", i: "îïíīįì", l: "ł", n: "ñń",
                o: "ôöòóœøōõ", s: "ßśš", u: "ûüùúū", y: "ÿ", z: "žźż" }, m = {}
    for (var b in acc)
        for (var i = 0; i < acc[b].length; ++i)
            m[acc[b][i]] = b
    return m
})()

function near(a, b) {
    var p = KEYPOS[a], q = KEYPOS[b]
    if (!p || !q)
        return false
    var dx = p.x - q.x, dy = p.y - q.y
    return dx * dx + dy * dy <= 1.6
}

function subCost(a, b) {
    if (a === b)
        return 0
    if ((BASE[a] || a) === (BASE[b] || b))
        return 0.3
    return near(a, b) ? 0.55 : 1
}

// Weighted edit distance (optimal string alignment). a = typed, b = candidate.
// Gives up once the cost must exceed max.
// Works in whole hundredths with Math.min: the Qt 5.6 JIT on 64-bit ARM (Sailfish
// phones) crashes on the same loop written with fractional costs and comparisons.
function distance(a, b, max) {
    var n = a.length, m = b.length
    if (Math.abs(n - m) > max * 2)
        return max + 1
    var lim = Math.round(max * 100), prev2 = [], prev = [0], cur, i, j, ca, cb, extra, rowMin, v
    for (j = 1; j <= m; ++j)
        prev.push(prev[j - 1] + ((j > 1 && b.charAt(j - 1) === b.charAt(j - 2)) ? 35 : 100))
    for (i = 1; i <= n; ++i) {
        ca = a.charAt(i - 1)
        // An extra typed letter is cheap when it repeats or touches its neighbour.
        extra = (i > 1 && a.charAt(i - 2) === ca) ? 35 : (i > 1 && near(a.charAt(i - 2), ca)) ? 70 : 100
        cur = [prev[0] + extra]
        rowMin = cur[0]
        for (j = 1; j <= m; ++j) {
            cb = b.charAt(j - 1)
            v = Math.min(prev[j - 1] + Math.round(subCost(ca, cb) * 100), prev[j] + extra,
                         cur[j - 1] + ((j > 1 && b.charAt(j - 2) === cb) ? 35 : 100))
            if (i > 1 && j > 1 && ca === b.charAt(j - 2) && a.charAt(i - 2) === cb)
                v = Math.min(v, prev2[j - 2] + 60)
            cur.push(v)
            rowMin = Math.min(rowMin, v)
        }
        if (rowMin > lim)
            return max + 1
        prev2 = prev
        prev = cur
    }
    return prev[m] / 100
}

function maxCost(n) {
    return n <= 2 ? 0.6 : n <= 4 ? 1.1 : n <= 7 ? 1.6 : 2.1
}

var ALPHABET = "abcdefghijklmnopqrstuvwxyz"
var NEAR = (function () {
    var m = {}
    for (var a in KEYPOS) {
        m[a] = ""
        for (var b in KEYPOS)
            if (a !== b && near(a, b))
                m[a] += b
    }
    return m
})()

// Spellings one edit away from w. full: every letter for substitutions and inserts;
// otherwise only the likely ones (neighbouring keys, doubled letters).
function edits(w, full, out) {
    var n = w.length, i, j, c, set
    for (i = 0; i < n; ++i)
        out.push(w.slice(0, i) + w.slice(i + 1))
    for (i = 0; i + 1 < n; ++i)
        out.push(w.slice(0, i) + w[i + 1] + w[i] + w.slice(i + 2))
    for (i = 0; i < n; ++i) {
        set = full ? ALPHABET : (NEAR[w[i]] || "")
        for (j = 0; j < set.length; ++j)
            if (set[j] !== w[i])
                out.push(w.slice(0, i) + set[j] + w.slice(i + 1))
    }
    for (i = 0; i <= n; ++i) {
        if (full) {
            for (j = 0; j < 26; ++j)
                out.push(w.slice(0, i) + ALPHABET[j] + w.slice(i))
        } else if (i > 0) {
            out.push(w.slice(0, i) + w[i - 1] + w.slice(i))
        }
    }
    return out
}

// Best corrections for a typed word: [{w, cost, score}], best first.
// Candidates come from generated misspellings looked up in the word index, so the
// cost does not grow with the size of the dictionary.
function corrections(lw, max) {
    init()
    var bare = lw.replace(/'/g, "")
    var key = fold(lw)
    var best = []
    var looked = Object.create(null)
    function offer(w, cost) {
        if (w === lw || (w in hidden))
            return
        var s = logFreq(w) - 2.6 * cost
        for (var k = 0; k < best.length; ++k)
            if (best[k].w === w) {
                if (s > best[k].score) best[k] = { w: w, cost: cost, score: s }
                return
            }
        best.push({ w: w, cost: cost, score: s })
        best.sort(function (x, y) { return y.score - x.score })
        if (best.length > 4)
            best.pop()
    }
    function look(k) {
        if (looked[k])
            return
        looked[k] = true
        var list = foldMap[k]
        if (!list)
            return
        for (var i = 0; i < list.length; ++i) {
            var c = distance(bare, bareOf[list[i]], max)
            if (c <= max)
                offer(words[list[i]], c)
        }
    }
    look(key)
    var e1 = edits(key, true, [])
    for (var i = 0; i < e1.length; ++i)
        look(e1[i])
    if (max >= 1 && key.length >= 3) {
        var cheap = edits(key, false, [])
        for (var j = 0; j < cheap.length; ++j) {
            var e2 = edits(cheap[j], false, [])
            for (var k = 0; k < e2.length; ++k)
                look(e2[k])
        }
    }
    for (var uw in user.w) {
        if (user.w[uw] >= 2 && !(uw in rank) && Math.abs(uw.length - lw.length) <= 2) {
            var uc = distance(lw, uw, max)
            if (uc <= max)
                offer(uw, uc)
        }
    }
    return best
}

// Most common words starting with prefix (not the prefix itself).
function completions(lw, count) {
    init()
    var lo = 0, hi = sorted.length
    while (lo < hi) {
        var mid = (lo + hi) >> 1
        if (sorted[mid] < lw) lo = mid + 1; else hi = mid
    }
    var found = []
    for (var i = lo; i < sorted.length && sorted[i].indexOf(lw) === 0; ++i) {
        var w = sorted[i]
        if (w === lw || (w in hidden))
            continue
        if (found.length < count) {
            found.push(w)
        } else {
            var worst = 0
            for (var k = 1; k < found.length; ++k)
                if (rank[found[k]] > rank[found[worst]]) worst = k
            if (rank[w] < rank[found[worst]])
                found[worst] = w
        }
    }
    for (var uw in user.w)
        if (user.w[uw] >= 2 && uw !== lw && uw.indexOf(lw) === 0 && !(uw in rank))
            found.push(uw)
    found.sort(function (x, y) { return logFreq(y) - logFreq(x) })
    return found.slice(0, count)
}

// --- casing ----------------------------------------------------------------------------

function display(lw, typed) {
    var w = user.f.hasOwnProperty(lw) ? user.f[lw]
          : PROPER.hasOwnProperty(lw) ? PROPER[lw]
          : lw.indexOf("i'") === 0 ? "I" + lw.slice(1)
          : lw
    if (typed && typed.length > 1 && typed === typed.toUpperCase() && typed !== typed.toLowerCase())
        return w.toUpperCase()
    if (typed && typed[0] !== typed[0].toLowerCase())
        return w.charAt(0).toUpperCase() + w.slice(1)
    return w
}

// --- public ----------------------------------------------------------------------------

// What the bar shows while a word is being typed, and the autocorrection (if any)
// that a space or punctuation would apply.
//   { auto: "Hello" or "", items: ["hello", "help"] }
function suggest(typed) {
    init()
    var lw = typed.toLowerCase()
    var res = { auto: "", items: [] }
    if (lw === "" || /[0-9]/.test(lw))
        return res
    var known = isKnown(lw)
    var mixedCase = /[A-Z]/.test(typed.slice(1)) && typed !== typed.toUpperCase()
    var corr = []
    if (lw.length >= 2 && (!known || (rank[lw] > 8000 && userCount(lw) < 2)))
        corr = corrections(lw, maxCost(lw.length))

    var comp = completions(lw, 4)
    // An unfinished word ("hel") that leads to common words is not a typo.
    var leads = comp.length > 0 && corr.length > 0 && logFreq(comp[0]) - 1.0 > corr[0].score

    if (!mixedCase && corr.length > 0 && !leads) {
        var best = corr[0]
        if (!known) {
            res.auto = display(best.w, typed)
        } else if (best.cost <= 1.1 && rank[best.w] !== undefined && rank[best.w] < 3000
                   && rank[best.w] * 30 < rank[lw]) {
            res.auto = display(best.w, typed)        // a rare spelling of a common word
        }
    }
    // "i" -> "I", "monday" -> "Monday": known words that only need a capital.
    if (res.auto === "" && known && !mixedCase) {
        var proper = display(lw, typed)
        if (proper !== typed && proper.toLowerCase() === lw)
            res.auto = proper
    }

    var pool = []
    for (var i = 0; i < corr.length; ++i)
        pool.push({ w: corr[i].w, score: corr[i].score })
    for (var j = 0; j < comp.length; ++j)
        pool.push({ w: comp[j], score: logFreq(comp[j]) - (leads ? -100 : 1.5) })
    pool.sort(function (x, y) { return y.score - x.score })
    var seen = {}
    seen[lw] = true
    if (res.auto !== "") {
        res.items.push(res.auto)
        seen[res.auto.toLowerCase()] = true
    }
    for (var k = 0; k < pool.length && res.items.length < 2; ++k) {
        if (seen[pool[k].w])
            continue
        seen[pool[k].w] = true
        res.items.push(display(pool[k].w, typed))
    }
    return res
}

// Words to offer after a finished word (or at the start of a sentence).
function next(prev, sentenceStart) {
    init()
    var out = [], seen = {}
    function add(w) {
        var lw = w.toLowerCase()
        if (seen[lw] || (lw in hidden))
            return
        seen[lw] = true
        var d = display(lw, "")
        if (sentenceStart)
            d = d.charAt(0).toUpperCase() + d.slice(1)
        out.push(d)
    }
    var lp = prev ? prev.toLowerCase() : ""
    if (lp !== "" && user.b.hasOwnProperty(lp)) {
        var nexts = user.b[lp], list = Object.keys(nexts)
        list.sort(function (x, y) { return nexts[y] - nexts[x] })
        for (var i = 0; i < list.length && out.length < 3; ++i)
            add(list[i])
    }
    var defaults = sentenceStart ? ["i", "the", "i'm"] : ["the", "to", "and"]
    for (var j = 0; j < defaults.length && out.length < 3; ++j)
        add(defaults[j])
    return out
}
