.pragma library
.import "EmojiNames.js" as N

// All geometry is in "reference units": the keyboard is designed on a 618 x 495 canvas
// (the reference screenshot) and scaled to the real screen by Keyboard.qml.

var REF_W = 618
var REF_H = 495

var MARGIN = 9
var GAP = 9
var KEY_W = (REF_W - 2 * MARGIN - 9 * GAP) / 10   // 51.9
var PITCH = KEY_W + GAP                            // 60.9
var KEY_H = 64

var ROW_Y = [75, 156, 236, 316]
var ROW_H = [64, 64, 64, 65]
// Touch bands: a touch anywhere inside a band goes to the nearest key of that row,
// so the gaps between keys are never dead.
var BAND = [[66, 147], [147, 228], [228, 308], [308, 392], [392, REF_H]]

var SHIFT_X = 9, SHIFT_W = 70
var BKSP_X = 538, BKSP_W = 71
var ROW3_X = 100, ROW3_END = 517       // letters between shift and backspace

var STRIP_ICON = { cx: 60, cy: 437.5, size: 39 }

var ACCENTS = {
    "a": "àáâäæãåā", "c": "çćč", "e": "èéêëēėę", "i": "îïíīįì",
    "l": "ł", "n": "ñń", "o": "ôöòóœøōõ", "s": "ßśš", "u": "ûüùúū",
    "y": "ÿ", "z": "žźż"
}

function charRow(chars, x0, pitch, w, row) {
    var keys = []
    for (var i = 0; i < chars.length; ++i)
        keys.push({ type: "char", ch: chars[i], x: x0 + i * pitch, w: w, row: row })
    return keys
}

function spread(chars, row) {
    // Evenly fill the space between the two wide row-3 keys (numbers / symbols pages).
    var n = chars.length
    var w = (ROW3_END - ROW3_X - (n - 1) * GAP) / n
    return charRow(chars, ROW3_X, w + GAP, w, row)
}

function bottomRow(modeLabel, modeTarget) {
    return [
        { type: "mode", label: modeLabel, target: modeTarget, x: 9, w: 142, row: 3 },
        { type: "space", x: 161, w: 294, row: 3 },
        { type: "return", x: 465, w: 144, row: 3 },
        { type: "emoji", x: 9, w: 102, row: 4, bare: true }
    ]
}

function finish(keys) {
    for (var i = 0; i < keys.length; ++i) {
        var k = keys[i]
        k.index = i
        if (k.row < 4) {
            k.y = ROW_Y[k.row]
            k.h = ROW_H[k.row]
        } else {
            k.y = BAND[4][0]
            k.h = BAND[4][1] - BAND[4][0]
        }
        k.accents = (k.type === "char" && ACCENTS[k.ch]) ? ACCENTS[k.ch] : ""
    }
    return keys
}

function keysFor(page) {
    var keys
    if (page === "numbers") {
        keys = charRow("1234567890".split(""), MARGIN, PITCH, KEY_W, 0)
            .concat(charRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""], MARGIN, PITCH, KEY_W, 1))
            .concat([{ type: "mode", label: "#+=", target: "symbols", x: SHIFT_X, w: SHIFT_W, row: 2 }])
            .concat(spread([".", ",", "?", "!", "'"], 2))
            .concat([{ type: "backspace", x: BKSP_X, w: BKSP_W, row: 2 }])
            .concat(bottomRow("ABC", "letters"))
    } else if (page === "symbols") {
        keys = charRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="], MARGIN, PITCH, KEY_W, 0)
            .concat(charRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"], MARGIN, PITCH, KEY_W, 1))
            .concat([{ type: "mode", label: "123", target: "numbers", x: SHIFT_X, w: SHIFT_W, row: 2 }])
            .concat(spread([".", ",", "?", "!", "'"], 2))
            .concat([{ type: "backspace", x: BKSP_X, w: BKSP_W, row: 2 }])
            .concat(bottomRow("ABC", "letters"))
    } else {
        keys = charRow("qwertyuiop".split(""), MARGIN, PITCH, KEY_W, 0)
            .concat(charRow("asdfghjkl".split(""), MARGIN + PITCH / 2, PITCH, KEY_W, 1))
            .concat([{ type: "shift", x: SHIFT_X, w: SHIFT_W, row: 2 }])
            .concat(charRow("zxcvbnm".split(""), ROW3_X, PITCH, KEY_W, 2))
            .concat([{ type: "backspace", x: BKSP_X, w: BKSP_W, row: 2 }])
            .concat(bottomRow("123", "numbers"))
    }
    return finish(keys)
}

function bandOf(y) {
    for (var r = 0; r < BAND.length; ++r)
        if (y >= BAND[r][0] && y < BAND[r][1])
            return r
    return -1
}

// x, y in reference units. Returns the key object or null.
function hitTest(keys, x, y) {
    var row = bandOf(y)
    if (row < 0)
        return null
    var best = null, bestDist = 1e9
    for (var i = 0; i < keys.length; ++i) {
        var k = keys[i]
        if (k.row !== row)
            continue
        var d = x < k.x ? k.x - x : (x > k.x + k.w ? x - (k.x + k.w) : 0)
        if (d < bestDist) {
            bestDist = d
            best = k
        }
    }
    // The bottom strip only has the emoji key on the left.
    if (best && best.row === 4 && bestDist > 0)
        return null
    return best
}

var EMOJI = [
    { icon: "😀", list: "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥸 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕 🤑 🤠 😈 👿 👹 👺 🤡 💩 👻 💀 👽 🤖 🎃" },
    { icon: "👍", list: "👋 🤚 🖐 ✋ 🖖 👌 🤌 🤏 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 👐 🤲 🤝 🙏 💪 👀 👁 👅 👄 💋 🧠 👶 🧒 👦 👧 🧑 👱 👨 🧔 👩 🧓 👴 👵 🙍 🙎 🙅 🙆 💁 🙋 🙇 🤦 🤷 💃 🕺 👯 🚶 🏃 ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝" },
    { icon: "🐶", list: "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞 🐜 🐢 🐍 🦎 🐙 🦑 🦐 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🐅 🐆 🦓 🦍 🐘 🦛 🦏 🐪 🐫 🦒 🐃 🐂 🐄 🐎 🐖 🐏 🐑 🐐 🦌 🐕 🐈 🐓 🦃 🕊 🐇 🐁 🌵 🎄 🌲 🌳 🌴 🌱 🌿 🍀 🍁 🍂 🍃 🌷 🌹 🌺 🌸 🌼 🌻 🌞 🌝 🌚 🌙 ⭐ 🌟 ✨ ⚡ 🔥 🌈 ☀️ ⛅ ☁️ 🌧 ⛄ ❄️ 💧 🌊" },
    { icon: "🍔", list: "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶 🌽 🥕 🧄 🧅 🥔 🍠 🥐 🥯 🍞 🥖 🧀 🥚 🍳 🥞 🧇 🥓 🥩 🍗 🍖 🌭 🍔 🍟 🍕 🥪 🌮 🌯 🥗 🍝 🍜 🍲 🍛 🍣 🍱 🥟 🍤 🍙 🍚 🍘 🍥 🍢 🍡 🍧 🍨 🍦 🥧 🧁 🍰 🎂 🍮 🍭 🍬 🍫 🍿 🍩 🍪 🥛 ☕ 🍵 🧃 🥤 🍺 🍻 🥂 🍷 🥃 🍸 🍹" },
    { icon: "⚽", list: "⚽ 🏀 🏈 ⚾ 🥎 🎾 🏐 🏉 🥏 🎱 🏓 🏸 🏒 🏑 🥍 🏏 ⛳ 🏹 🎣 🥊 🥋 ⛸ 🎿 🛷 🏂 🏋️ 🤸 🤺 🏇 🧘 🏄 🏊 🚣 🧗 🚴 🏆 🥇 🥈 🥉 🏅 🎖 🎗 🎫 🎟 🎪 🎭 🎨 🎬 🎤 🎧 🎼 🎹 🥁 🎷 🎺 🎸 🎻 🎲 ♟ 🎯 🎳 🎮 🎰 🧩 🚗 🚕 🚙 🚌 🚎 🏎 🚓 🚑 🚒 🚐 🚚 🚛 🚜 🛵 🏍 🚲 🛴 🚨 🚔 🚍 🚘 🚖 🚡 🚠 🚟 🚃 🚋 🚞 🚝 🚄 🚅 🚈 🚂 🚆 🚇 🚊 🚉 ✈️ 🛫 🛬 🚀 🛸 🚁 ⛵ 🚤 🛥 🛳 ⛴ 🚢 ⚓ 🗺 🗽 🗼 🏰 🏯 🏟 🎡 🎢 🎠 ⛲ 🏖 🏝 🏜 🌋 ⛰ 🏔 🗻 🏕 ⛺ 🏠 🏡" },
    { icon: "💡", list: "⌚ 📱 💻 ⌨️ 🖥 🖨 🖱 💾 💿 📷 📹 🎥 📞 ☎️ 📺 📻 🎙 ⏰ ⌛ ⏳ 📡 🔋 🔌 💡 🔦 🕯 💸 💵 💶 💷 💰 💳 💎 ⚖️ 🔧 🔨 🛠 ⛏ 🔩 ⚙️ 🧱 🧲 🔫 💣 🔪 🗡 ⚔️ 🛡 🔮 💈 💊 💉 🧬 🦠 🌡 🧹 🧺 🧻 🚽 🚿 🛁 🔑 🗝 🚪 🛋 🛏 🖼 🛍 🛒 🎁 🎈 🎏 🎀 🎊 🎉 ✉️ 📩 📨 📧 💌 📦 📫 📜 📄 📑 📊 📈 📉 📅 📆 📇 📋 📁 📂 📰 📓 📔 📒 📕 📗 📘 📙 📚 📖 🔖 🔗 📎 📐 📏 📌 📍 ✂️ 🖊 🖋 ✒️ 🖌 🖍 📝 ✏️ 🔍 🔎 🔏 🔐 🔒 🔓" },
    { icon: "❤️", list: "❤️ 💯 💢 💥 💫 💦 💨 🕳 💬 💭 💤 ✅ ☑️ ✔️ ❌ ❎ ➕ ➖ ➗ ✖️ ♾ ‼️ ⁉️ ❓ ❔ ❕ ❗ 〰️ © ® ™ #️⃣ *️⃣ 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟 🔠 🔡 🔢 🔣 🔤 🅰️ 🆎 🅱️ 🆑 🆒 🆓 ℹ️ 🆔 Ⓜ️ 🆕 🆖 🅾️ 🆗 🅿️ 🆘 🆙 🆚 🔴 🟠 🟡 🟢 🔵 🟣 ⚫ ⚪ 🟤 🔺 🔻 🔸 🔹 🔶 🔷 🔳 🔲 ▪️ ▫️ ◾ ◽ ◼️ ◻️ ⬛ ⬜ 🔈 🔇 🔉 🔊 🔔 🔕 📣 📢 ♻️ ⚠️ 🚸 ⛔ 🚫 🚳 🚭 🚯 🚱 🚷 🔞 ☢️ ☣️ ⬆️ ↗️ ➡️ ↘️ ⬇️ ↙️ ⬅️ ↖️ ↕️ ↔️ ↩️ ↪️ 🔃 🔄 🔙 🔚 🔛 🔜 🔝" }
]

// Colour picture for an emoji (Noto Emoji 3D, see scripts/fetch_emoji.py): code points
// in hex without FE0F, joined by "_". Qt 5.6 cannot draw colour emoji fonts.
function emojiFile(e) {
    var parts = []
    for (var i = 0; i < e.length; ++i) {
        var c = e.charCodeAt(i)
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < e.length) {
            c = (c - 0xD800) * 0x400 + (e.charCodeAt(i + 1) - 0xDC00) + 0x10000
            ++i
        }
        if (c === 0xFE0F)
            continue
        var h = c.toString(16)
        while (h.length < 4)
            h = "0" + h
        parts.push(h)
    }
    return "emoji/" + parts.join("_") + ".png"
}

function emojiList() {
    var all = [], starts = []
    for (var c = 0; c < EMOJI.length; ++c) {
        starts.push(all.length)
        all = all.concat(EMOJI[c].list.split(" "))
    }
    return { all: all, starts: starts }
}

// Emoji search. Every word of the query must start a word of the emoji's name or of
// one of its keywords; name matches rank above keyword matches, and emoji keep their
// page order otherwise. Returns up to max emoji.
var searchIndex = null

// Lower case, accents off (from ACCENTS: "piña" -> "pina"), apostrophes dropped ("i’m" -> "im").
var plainOf = null
function foldSearch(s) {
    if (!plainOf) {
        plainOf = {}
        for (var base in ACCENTS)
            for (var i = 0; i < ACCENTS[base].length; ++i)
                plainOf[ACCENTS[base].charAt(i)] = base
        plainOf["ō"] = "o"
    }
    var out = ""
    s = s.toLowerCase()
    for (var j = 0; j < s.length; ++j) {
        var c = s.charAt(j)
        if (c === "'" || c === "\u2019")
            continue
        out += plainOf[c] || c
    }
    return out
}

function wordsOf(s) {
    return foldSearch(s).split(/[\s\-:,.!?\u201C\u201D"()]+/).filter(function (w) { return w !== "" })
}

function emojiSearchIndex() {
    if (searchIndex)
        return searchIndex
    searchIndex = []
    var all = emojiList().all
    for (var i = 0; i < all.length; ++i) {
        var names = N.NAMES[all[i]]
        if (!names)
            continue
        var parts = names.split("|")
        var kw = []
        for (var j = 1; j < parts.length; ++j)
            kw = kw.concat(wordsOf(parts[j]))
        searchIndex.push({ e: all[i], name: foldSearch(parts[0]), nameWords: wordsOf(parts[0]), words: kw })
    }
    return searchIndex
}

// 2 if a word of list is t, 1 if one starts with t, else 0.
function startsAny(list, t) {
    var best = 0
    for (var i = 0; i < list.length; ++i)
        if (list[i].indexOf(t) === 0) {
            if (list[i] === t)
                return 2
            best = 1
        }
    return best
}

function searchEmoji(query, max) {
    var q = foldSearch(query).replace(/^\s+|\s+$/g, "")
    var tokens = wordsOf(q)
    if (tokens.length === 0)
        return []
    var idx = emojiSearchIndex(), found = []
    for (var i = 0; i < idx.length; ++i) {
        var it = idx[i], score = 0
        for (var t = 0; t < tokens.length; ++t) {
            var inName = startsAny(it.nameWords, tokens[t])
            var s = inName ? 2 + inName : startsAny(it.words, tokens[t])
            if (s === 0) {
                score = -1
                break
            }
            score += s
        }
        if (score < 0)
            continue
        if (it.name === q)
            score += 20
        // Shorter names are the plainer emoji: "red heart" before "smiling face with heart-eyes".
        score -= 0.1 * it.nameWords.length
        found.push({ e: it.e, score: score, order: i })
    }
    found.sort(function (a, b) { return b.score - a.score || a.order - b.order })
    return found.slice(0, max || 60).map(function (f) { return f.e })
}
