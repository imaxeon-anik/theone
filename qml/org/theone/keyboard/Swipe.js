.pragma library
.import "Predict.js" as P
.import "Layouts.js" as L

// Swipe typing: turns the path a finger draws across the letters into words.
// Each candidate word has an ideal path (straight lines between its letters' key
// centres). Both paths are resampled to the same number of points and compared point
// by point; the closest shapes win, weighed with how common each word is.
// Coordinates are in Layouts.js reference units.

var N = 32             // points each path is resampled to
var PITCH = L.PITCH
var START_R = 0.95 * L.PITCH   // how far from the first / last letter a path may start / end
var LETTER_R = 1.05 * L.PITCH  // every letter of a word must pass this close to the path
var SIGMA = 17         // shape distance (units) that counts as one "step" worse
var FREQ = 0.55        // weight of word frequency against shape

var centre = null      // letter -> { x, y }
var index = null       // "first+last letter" -> [word rank, ...], most common first

function centres() {
    if (centre)
        return centre
    centre = {}
    var keys = L.keysFor("letters")
    for (var i = 0; i < keys.length; ++i) {
        var k = keys[i]
        if (k.type === "char")
            centre[k.ch] = { x: k.x + k.w / 2, y: k.y + k.h / 2 }
    }
    return centre
}

// The letters a word is swiped through: no apostrophes or accents, no doubled letters.
function keysOf(w) {
    var f = P.fold(w), out = ""
    for (var i = 0; i < f.length; ++i) {
        var c = f.charAt(i)
        if (c < "a" || c > "z")
            return ""
        if (c !== out.charAt(out.length - 1))
            out += c
    }
    return out
}

// Index only the first and last letters here (fast); a word's full key sequence is
// worked out the first time a swipe could match it.
function buildIndex() {
    if (index)
        return
    P.init()
    index = Object.create(null)
    var plain = /^[a-z]+$/
    for (var i = 0; i < P.words.length; ++i) {
        var w = P.words[i]
        var b = P.bareOf[i]
        if (!plain.test(b)) {
            b = P.fold(w)
            if (!plain.test(b))
                continue
        }
        if (b.length < 2 || (w in P.hidden))
            continue
        var key = b.charAt(0) + b.charAt(b.length - 1)
        var list = index[key]
        if (!list)
            list = index[key] = []
        list.push(i)
    }
}

var keysCache = Object.create(null)
function cachedKeys(w) {
    var k = keysCache[w]
    if (k === undefined)
        k = keysCache[w] = keysOf(w)
    return k
}

function dist(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y
    return Math.sqrt(dx * dx + dy * dy)
}

function pathLength(pts) {
    var len = 0
    for (var i = 1; i < pts.length; ++i)
        len += dist(pts[i - 1], pts[i])
    return len
}

// n points spread evenly along the path.
function resample(pts, n) {
    var out = [{ x: pts[0].x, y: pts[0].y }]
    var total = pathLength(pts)
    if (total === 0 || pts.length < 2) {
        while (out.length < n)
            out.push({ x: pts[0].x, y: pts[0].y })
        return out
    }
    var step = total / (n - 1), carried = 0
    var prev = { x: pts[0].x, y: pts[0].y }
    var i = 1
    while (i < pts.length && out.length < n - 1) {
        var d = dist(prev, pts[i])
        if (carried + d >= step && d > 0) {
            var t = (step - carried) / d
            prev = { x: prev.x + t * (pts[i].x - prev.x), y: prev.y + t * (pts[i].y - prev.y) }
            out.push(prev)
            carried = 0
        } else {
            carried += d
            prev = pts[i]
            ++i
        }
    }
    var last = pts[pts.length - 1]
    while (out.length < n)
        out.push({ x: last.x, y: last.y })
    return out
}

function idealPath(keys) {
    var c = centres(), pts = []
    for (var i = 0; i < keys.length; ++i)
        pts.push(c[keys.charAt(i)])
    return pts
}

// Letters within r of p; if none (the finger ran off the letters, onto the space bar
// say), the closest one.
function lettersNear(p, r) {
    var c = centres(), out = [], closest = "", best = 1e9
    for (var ch in c) {
        var d = dist(p, c[ch])
        if (d <= r)
            out.push(ch)
        if (d < best) {
            best = d
            closest = ch
        }
    }
    if (out.length === 0)
        out.push(closest)
    return out
}

// The words a swipe most likely meant, best first: [{ w, score }].
// points: [{ x, y }, ...] in reference units. prev: the word before, for bigrams.
function decode(points, prev, count) {
    var res = match(points, prev, count, LETTER_R)
    // A sloppy swipe can miss a middle letter by more than that; rather than write
    // nothing, look again with a wider margin.
    if (res.length === 0)
        res = match(points, prev, count, 2 * LETTER_R)
    return res
}

function match(points, prev, count, letterR) {
    if (!points || points.length < 2)
        return []
    buildIndex()
    count = count || 4
    var c = centres()
    var path = resample(points, N)
    var len = pathLength(points)

    // How close the path comes to each letter.
    var near = {}
    for (var ch in c) {
        var best = 1e9
        for (var j = 0; j < path.length; ++j) {
            var d = dist(path[j], c[ch])
            if (d < best) best = d
        }
        near[ch] = best
    }

    var firsts = lettersNear(points[0], START_R)
    var lasts = lettersNear(points[points.length - 1], START_R)
    var lp = prev ? prev.toLowerCase() : ""
    var follows = (lp !== "" && P.user.b.hasOwnProperty(lp)) ? P.user.b[lp] : null

    var found = [], seen = Object.create(null)
    function consider(w, keys) {
        if (seen[w])
            return
        for (var i = 1; i < keys.length - 1; ++i)
            if (near[keys.charAt(i)] > letterR)
                return
        var ideal = idealPath(keys)
        var il = pathLength(ideal)
        if (il > 2.2 * len + PITCH || len > 2.2 * il + 2 * PITCH)
            return
        seen[w] = true
        var model = resample(ideal, N), sum = 0
        for (var k = 0; k < N; ++k)
            sum += dist(path[k], model[k])
        var shape = sum / N / SIGMA
        var score = -shape * shape + FREQ * P.logFreq(w)
        if (follows && follows[w])
            score += 0.7 * Math.log(1 + follows[w])
        found.push({ w: w, score: score })
    }

    for (var a = 0; a < firsts.length; ++a)
        for (var b = 0; b < lasts.length; ++b) {
            var list = index[firsts[a] + lasts[b]]
            if (!list)
                continue
            for (var m = 0; m < list.length; ++m) {
                var w = P.words[list[m]], k = cachedKeys(w)
                if (k.length >= 2)
                    consider(w, k)
            }
        }
    // Words the user has taught the keyboard.
    for (var uw in P.user.w) {
        if (P.user.w[uw] < 2 || (uw in P.rank))
            continue
        var uk = keysOf(uw)
        if (uk.length >= 2 && firsts.indexOf(uk.charAt(0)) >= 0 && lasts.indexOf(uk.charAt(uk.length - 1)) >= 0)
            consider(uw, uk)
    }

    found.sort(function (x, y) { return y.score - x.score })
    return found.slice(0, count)
}
