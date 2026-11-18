.pragma library

// The braindance editor's helpers (launcher/Braindance.qml): what kind of thing a clip is (its track),
// and what's hidden in it (the DECODED layer: a link's parts, JSON laid out, a colour, a timestamp,
// base64 or a JWT decoded, a number in other bases, a path's parts).

var KINDS = ["link", "code", "path", "text", "image"];

function kindOf(it) {
    if (it.preview_type === "file") return "image";
    var s = (it.text || "").trim();
    if (/^[a-z][a-z0-9+.-]*:\/\/\S+$/i.test(s) || /^www\.\S+\.\S+$/i.test(s)) return "link";
    if (/^(~\/|\/|\.\.?\/)[^\n]{0,400}$/.test(s) && (s.match(/ /g) || []).length <= 3 && !/[;|&]/.test(s)) return "path";
    if (looksCode(s)) return "code";
    return "text";
}

function looksCode(s) {
    if (/^[\[{]/.test(s) && parseJson(s) !== undefined) return true;
    if (/^(sudo|git|cd|ls|cat|cp|mv|rm|mkdir|yay|paru|pacman|systemctl|journalctl|hyprctl|qs|npm|npx|pnpm|yarn|pip|uv|python3?|node|cargo|make|docker|podman|ssh|scp|rsync|curl|wget|chmod|chown|grep|rg|find|sed|awk|echo|export|kitty|flatpak|tailscale|nmcli|ffmpeg|magick|ping|go|gcc|vim|nvim|tar|unzip|kill|pkill|ln|touch|ip|dig|lsblk|mount|umount|swaymsg|claude|gh)\s/.test(s)) return true;
    if (/(=>|::|\$\(|&&|\|\||\s\|\s)/.test(s)) return true;
    if (/^\s*(import|from|def|class|function|const|let|var|return|if|for|while|#include|public|private|package|fn|local)\b/m.test(s) && /[(){}=:;]/.test(s)) return true;
    var lines = s.split("\n");
    var indented = lines.filter(function (l) { return /^(\s{2,}|\t)/.test(l); }).length;
    if (lines.length > 2 && indented >= 2 && /[;{}=]/.test(s)) return true;
    // YAML / config: several "key: value" lines, some indented
    if (lines.length > 2 && indented >= 1 && lines.filter(function (l) { return /^\s*[\w.-]+:(\s|$)/.test(l); }).length >= 3) return true;
    return false;
}

function parseJson(s) {
    try { return JSON.parse(s); } catch (e) { return undefined; }
}

// ---------------------------------------------------------------- base64 (and base64url) to text
function b64bytes(s) {
    var abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    s = s.replace(/-/g, "+").replace(/_/g, "/").replace(/[\s=]/g, "");
    var out = [], buf = 0, bits = 0;
    for (var i = 0; i < s.length; i++) {
        var v = abc.indexOf(s[i]);
        if (v < 0) return null;
        buf = (buf << 6) | v; bits += 6;
        if (bits >= 8) { bits -= 8; out.push((buf >> bits) & 0xff); }
    }
    return out;
}
function utf8(bytes) {
    var s = "", i = 0;
    while (i < bytes.length) {
        var c = bytes[i++];
        if (c < 0x80) s += String.fromCharCode(c);
        else if (c >= 0xc0 && c < 0xe0 && i < bytes.length) s += String.fromCharCode(((c & 0x1f) << 6) | (bytes[i++] & 0x3f));
        else if (c >= 0xe0 && c < 0xf0 && i + 1 < bytes.length) { s += String.fromCharCode(((c & 0x0f) << 12) | ((bytes[i] & 0x3f) << 6) | (bytes[i + 1] & 0x3f)); i += 2; }
        else if (c >= 0xf0 && i + 2 < bytes.length) {
            var cp = ((c & 0x07) << 18) | ((bytes[i] & 0x3f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f); i += 3;
            cp -= 0x10000; s += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff));
        } else return null;
    }
    return s;
}
function printable(s) {
    if (!s) return false;
    var bad = 0;
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if (c < 9 || (c > 13 && c < 32) || c === 0xfffd) bad++;
    }
    return bad / s.length < 0.02;
}

function bytes(s) {       // UTF-8 length
    var n = 0;
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        n += c < 0x80 ? 1 : c < 0x800 ? 2 : (c >= 0xd800 && c < 0xdc00) ? (i++, 4) : 3;
    }
    return n;
}

function pad(n) { return (n < 10 ? "0" : "") + n; }
function stamp(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "  " + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
}
function ago(ms) {
    var s = Math.max(0, ms / 1000);
    if (s < 60) return "JUST NOW";
    if (s < 3600) return Math.floor(s / 60) + " MIN AGO";
    if (s < 86400) return Math.floor(s / 3600) + " H " + Math.floor((s % 3600) / 60) + " MIN AGO";
    return Math.floor(s / 86400) + " D " + Math.floor((s % 86400) / 3600) + " H AGO";
}
function gap(s) {         // a cut's length: "9H 12M", "2D 3H"
    if (s >= 86400) return Math.floor(s / 86400) + "D " + Math.floor((s % 86400) / 3600) + "H";
    if (s >= 3600) return Math.floor(s / 3600) + "H " + Math.floor((s % 3600) / 60) + "M";
    return Math.floor(s / 60) + "M";
}

function hsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b), h = 0, s = 0, l = (mx + mn) / 2;
    if (mx !== mn) {
        var d = mx - mn;
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
        h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
        h *= 60;
    }
    return Math.round(h) + "°  " + Math.round(s * 100) + "%  " + Math.round(l * 100) + "%";
}

// ---------------------------------------------------------------- the DECODED layer
// -> { title, rows: [[key, value]], code: "", swatch: "" }   (title "" = nothing hidden)
function decode(it, kind, now) {
    var r = { title: "", rows: [], code: "", swatch: "" };
    if (kind === "image") return r;
    var s = (it.text || "").trim();
    var m;

    m = s.match(/^([a-z][a-z0-9+.-]*):\/\/(?:([^@\/?#]*)@)?([^\/?#:]*)(?::(\d+))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?$/i);
    if (m) {
        r.title = "LINK  //  " + m[3].toUpperCase();
        r.rows.push(["SCHEME", m[1]]);
        if (m[2]) r.rows.push(["USER", m[2]]);
        r.rows.push(["HOST", m[3]]);
        if (m[4]) r.rows.push(["PORT", m[4]]);
        var segs = m[5].split("/").filter(function (x) { return x; });
        if (segs.length) r.rows.push(["PATH", segs.join("  /  ")]);
        if (m[6]) m[6].split("&").forEach(function (kv) {
            var i = kv.indexOf("="), k = i < 0 ? kv : kv.slice(0, i), v = i < 0 ? "" : kv.slice(i + 1);
            try { v = decodeURIComponent(v.replace(/\+/g, " ")); } catch (e) {}
            r.rows.push(["?" + k, v]);
        });
        if (m[7]) r.rows.push(["FRAGMENT", m[7]]);
        return r;
    }

    if (/^eyJ[\w-]*\.[\w-]*\.[\w-]*$/.test(s)) {
        var parts = s.split("."), hb = b64bytes(parts[0]), pb = b64bytes(parts[1]);
        var head = hb ? parseJson(utf8(hb)) : undefined, body = pb ? parseJson(utf8(pb)) : undefined;
        if (head !== undefined && body !== undefined) {
            r.title = "JWT  //  " + (head.alg || "?");
            ["iat", "nbf", "exp"].forEach(function (k) {
                if (typeof body[k] === "number") r.rows.push([k.toUpperCase(), stamp(new Date(body[k] * 1000)) + (k === "exp" && body[k] * 1000 < now ? "  //  EXPIRED" : "")]);
            });
            r.code = JSON.stringify(head, null, 2) + "\n" + JSON.stringify(body, null, 2);
            return r;
        }
    }

    if (/^[\[{]/.test(s)) {
        var j = parseJson(s);
        if (j !== undefined) {
            r.title = Array.isArray(j) ? "JSON  //  " + j.length + " ITEMS" : "JSON  //  " + Object.keys(j).length + " KEYS";
            r.code = JSON.stringify(j, null, 2).slice(0, 8000);
            return r;
        }
    }

    m = s.match(/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i) || (/\d/.test(s) && s.match(/^([0-9a-f]{6}|[0-9a-f]{8})$/i));
    if (m) {
        var h = m[1].length === 3 ? m[1].split("").map(function (c) { return c + c; }).join("") : m[1];
        var R = parseInt(h.slice(0, 2), 16), G = parseInt(h.slice(2, 4), 16), B = parseInt(h.slice(4, 6), 16);
        r.title = "COLOUR";
        r.swatch = "#" + h.slice(0, 6);
        r.rows.push(["HEX", "#" + h.toUpperCase()], ["RGB", R + "  " + G + "  " + B], ["HSL", hsl(R, G, B)]);
        if (h.length === 8) r.rows.push(["ALPHA", Math.round(parseInt(h.slice(6, 8), 16) / 2.55) + "%"]);
        return r;
    }
    m = s.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i);
    if (m) {
        var rr = +m[1], gg = +m[2], bb = +m[3];
        r.title = "COLOUR";
        var hex = [rr, gg, bb].map(function (x) { x = Math.min(255, x); return (x < 16 ? "0" : "") + x.toString(16); }).join("");
        r.swatch = "#" + hex;
        r.rows.push(["HEX", "#" + hex.toUpperCase()], ["HSL", hsl(rr, gg, bb)]);
        return r;
    }

    if (/^\d{10}$/.test(s) || /^\d{13}$/.test(s)) {
        var ms = s.length === 10 ? +s * 1000 : +s;
        var d = new Date(ms);
        r.title = "UNIX TIME";
        r.rows.push(["LOCAL", stamp(d)], ["UTC", d.toISOString().replace("T", "  ").replace(/\.\d+Z$/, "")], [ms < now ? "AGO" : "IN", ago(Math.abs(now - ms)).replace(" AGO", "")]);
        return r;
    }
    if (/^(0x[0-9a-f]+|0b[01]+|\d{1,15})$/i.test(s)) {
        var n = s.startsWith("0b") ? parseInt(s.slice(2), 2) : Number(s);
        r.title = "NUMBER";
        r.rows.push(["DEC", String(n)], ["HEX", "0x" + n.toString(16).toUpperCase()]);
        if (n < 4294967296) r.rows.push(["BIN", n.toString(2).replace(/\B(?=(\d{4})+(?!\d))/g, " ")]);
        r.rows.push(["OCT", "0o" + n.toString(8)]);
        return r;
    }

    var compact = s.replace(/\s/g, "");
    if (compact.length >= 16 && compact.length % 4 === 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(compact)) {
        var bytes = b64bytes(compact), txt = bytes ? utf8(bytes) : null;
        if (txt && printable(txt)) {
            r.title = "BASE64  //  " + bytes.length + " BYTES";
            var jj = /^[\[{]/.test(txt.trim()) ? parseJson(txt) : undefined;
            r.code = (jj !== undefined ? JSON.stringify(jj, null, 2) : txt).slice(0, 8000);
            return r;
        }
    }

    if (kind === "path") {
        var p = s.replace(/^file:\/\//, ""), slash = p.lastIndexOf("/");
        var name = p.slice(slash + 1), dot = name.lastIndexOf(".");
        r.title = "PATH";
        r.rows.push(["FOLDER", slash > 0 ? p.slice(0, slash) : "/"], ["NAME", name || "(folder)"]);
        if (dot > 0) r.rows.push(["TYPE", name.slice(dot + 1).toUpperCase()]);
        r.rows.push(["DEPTH", String(p.split("/").filter(function (x) { return x; }).length)]);
        return r;
    }

    if (kind === "code" && s.indexOf("\n") < 0 && /(&&|\|\||\s\|\s|;\s)/.test(s)) {
        var steps = s.split(/\s*(&&|\|\||\||;)\s*/);
        r.title = "PIPELINE  //  " + Math.ceil(steps.length / 2) + " STEPS";
        var out = [];
        for (var k = 0; k < steps.length; k += 2) out.push((k ? steps[k - 1] + "  " : "    ") + steps[k]);
        r.code = out.join("\n");
        return r;
    }
    return r;
}
