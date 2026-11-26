.pragma library

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
