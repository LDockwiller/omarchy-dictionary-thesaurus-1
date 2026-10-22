.pragma library

var MAX_DEFINITIONS = 3
var MAX_SYNONYMS = 10
var MAX_ANTONYMS = 6

// Errors are returned as keys so the panel can show them in the active language.
function parse(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, error: "noData" }

  try {
    var payload = JSON.parse(text)
    if (payload && payload.language === "fr") {
      if (typeof payload.wikitext !== "string")
        return { ok: false, error: "unexpected" }
      return wiktionary(payload.wikitext)
    }
    if (!payload || !Array.isArray(payload.synonyms) || !Array.isArray(payload.antonyms))
      return { ok: false, error: "unexpected" }
    return {
      ok: true,
      definitions: definitions(payload.dictionary),
      synonyms: words(payload.synonyms),
      antonyms: words(payload.antonyms)
    }
  } catch (error) {
    return { ok: false, error: "unreadable" }
  }
}

function definitions(entries) {
  if (!Array.isArray(entries)) return []
  var result = []
  var seenParts = {}

  for (var i = 0; i < entries.length && result.length < MAX_DEFINITIONS; i++) {
    var meanings = Array.isArray(entries[i].meanings) ? entries[i].meanings : []
    for (var j = 0; j < meanings.length && result.length < MAX_DEFINITIONS; j++) {
      var part = String(meanings[j].partOfSpeech || "").trim()
      var partKey = part.toLowerCase()
      if (seenParts[partKey]) continue
      var rows = Array.isArray(meanings[j].definitions) ? meanings[j].definitions : []
      for (var k = 0; k < rows.length; k++) {
        var text = String(rows[k] && rows[k].definition || "").trim()
        if (text !== "") {
          seenParts[partKey] = true
          result.push({ part: part, text: text })
          break
        }
      }
    }
  }
  return result
}

function words(rows) {
  var result = []
  var seen = {}
  for (var i = 0; i < rows.length; i++) {
    var word = String(rows[i] && rows[i].word || "").trim()
    var key = word.toLowerCase()
    if (word !== "" && !seen[key]) {
      seen[key] = true
      result.push(word)
    }
  }
  return result
}

// Reads the French section of a fr.wiktionary.org page. Definitions are the
// `# ` lines under each part-of-speech heading; synonyms and antonyms are the
// links listed under the matching `{{S|synonymes}}` / `{{S|antonymes}}` headings.
function wiktionary(wikitext) {
  var lines = String(wikitext || "").split("\n")
  var inFrench = false
  var section = ""
  var parts = []
  var byPart = {}
  var synonymRows = []
  var antonymRows = []

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]

    var language = line.match(/^==\s*\{\{langue\|([^|}]+)/)
    if (language) {
      inFrench = language[1].trim() === "fr"
      section = ""
      continue
    }
    if (!inFrench) continue

    var heading = line.match(/^===+\s*\{\{S\|([^|}]+)/)
    if (heading) {
      section = heading[1].trim()
      continue
    }
    if (/^==/.test(line)) {
      section = ""
      continue
    }

    if (section === "synonymes" || section === "antonymes") {
      if (!/^\*/.test(line)) continue
      var link = line.match(/\[\[([^\]|#]+)|\{\{(?:lien|l)\|([^|}]+)/)
      if (!link) continue
      var word = (link[1] || link[2]).trim()
      if (!/[A-Za-zÀ-ÿœŒ]/.test(word)) continue
      var rows = section === "synonymes" ? synonymRows : antonymRows
      rows.push({ word: word })
      continue
    }

    var definition = line.match(/^#(?![*:#])\s*(.*)$/)
    if (definition && section !== "") {
      var text = cleanWikitext(definition[1])
      if (text === "") continue
      if (!byPart[section]) {
        byPart[section] = []
        parts.push(section)
      }
      byPart[section].push(text)
    }
  }

  // Round-robin across parts of speech so a word that is both a noun and an
  // adjective shows both before a second sense of either.
  var result = []
  for (var round = 0; result.length < MAX_DEFINITIONS; round++) {
    var added = false
    for (var p = 0; p < parts.length && result.length < MAX_DEFINITIONS; p++) {
      if (round < byPart[parts[p]].length) {
        result.push({ part: parts[p], text: byPart[parts[p]][round] })
        added = true
      }
    }
    if (!added) break
  }

  return {
    ok: true,
    definitions: result,
    synonyms: words(synonymRows).slice(0, MAX_SYNONYMS),
    antonyms: words(antonymRows).slice(0, MAX_ANTONYMS)
  }
}

function cleanWikitext(text) {
  var s = String(text || "")
  s = s.replace(/<ref[^>]*\/>/g, "").replace(/<ref[^>]*>[\s\S]*?<\/ref>/g, "")
  s = s.replace(/<[^>]+>/g, "")

  // Expand templates innermost first so nested ones collapse cleanly.
  var previous
  do {
    previous = s
    s = s.replace(/\{\{([^{}]*)\}\}/g, function(match, body) { return template(body) })
  } while (s !== previous)

  s = s.replace(/\[\[[^\]|]*\|([^\]]*)\]\]/g, "$1")
  s = s.replace(/\[\[([^\]]*)\]\]/g, "$1")
  s = s.replace(/'{2,}/g, "")
  return s.replace(/\s+/g, " ").trim()
}

function template(body) {
  var pieces = body.split("|")
  var name = pieces[0].trim()
  var positional = []
  for (var i = 1; i < pieces.length; i++) {
    if (pieces[i].indexOf("=") === -1) positional.push(pieces[i].trim())
  }

  if (name === "note") return ""
  if (name === "term" || name === "term_lien" || name === "sens")
    return positional.length > 0 ? "(" + positional[0] + ")" : ""
  if (name === "lien" || name === "l" || name === "w")
    return positional.length > 0 ? positional[positional.length > 1 && name === "w" ? 1 : 0] : ""

  // Usage and domain labels such as {{familier|fr}} or {{figuré|fr}}.
  var onlyLanguage = positional.length === 0 || (positional.length === 1 && /^[a-z]{2,3}$/.test(positional[0]))
  if (onlyLanguage && /^[a-zàâäçéèêëîïôöûùüÿœ' -]+$/i.test(name))
    return "(" + name.charAt(0).toUpperCase() + name.slice(1) + ")"
  return ""
}
