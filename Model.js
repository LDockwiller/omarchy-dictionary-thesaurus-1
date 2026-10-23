.pragma library

var MAX_EN_SENSES = 3
var MAX_FR_SENSES = 25
var MAX_SYNONYMS = 30
var MAX_ANTONYMS = 10
var MAX_EXAMPLE_LENGTH = 240

// Errors are returned as keys so the panel can show them in the active language.
//
// A successful result looks like:
//   { ok, pronunciation, etymology,
//     entries: [{ part, info, pronunciation, senses: [{ label, level, text, example }] }],
//     synonyms / antonyms: [{ sense, words: [{ word, note }] }] }
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
    var english = englishEntries(payload.dictionary)
    return {
      ok: true,
      pronunciation: english.pronunciation,
      etymology: english.etymology,
      entries: english.entries,
      synonyms: flatGroup(words(payload.synonyms).slice(0, MAX_SYNONYMS)),
      antonyms: flatGroup(words(payload.antonyms).slice(0, MAX_ANTONYMS))
    }
  } catch (error) {
    return { ok: false, error: "unreadable" }
  }
}

function senseCount(entries) {
  var count = 0
  for (var i = 0; i < entries.length; i++) count += entries[i].senses.length
  return count
}

// Plain-text version of the results for the clipboard.
function plainText(result, query, labels) {
  var lines = [query + (result.pronunciation ? "  /" + result.pronunciation + "/" : "")]
  for (var i = 0; i < result.entries.length; i++) {
    var entry = result.entries[i]
    lines.push("")
    lines.push(entry.part + (entry.info ? " · " + entry.info : ""))
    for (var j = 0; j < entry.senses.length; j++) {
      var sense = entry.senses[j]
      var indent = sense.level > 1 ? "    " : ""
      lines.push(indent + sense.label + " " + sense.text)
      if (sense.example) lines.push(indent + "   « " + sense.example + " »")
    }
  }
  if (result.etymology) lines.push("", labels.etymology + " : " + result.etymology)
  relationText(lines, labels.synonyms, result.synonyms)
  relationText(lines, labels.antonyms, result.antonyms)
  return lines.join("\n")
}

function relationText(lines, label, groups) {
  if (wordCount(groups) === 0) return
  lines.push("", label)
  for (var i = 0; i < groups.length; i++) {
    var items = groups[i].words.map(function(item) { return item.word + (item.note ? " (" + item.note + ")" : "") })
    lines.push((groups[i].sense ? groups[i].sense + " : " : "") + items.join(", "))
  }
}

function wordCount(groups) {
  var count = 0
  for (var i = 0; i < groups.length; i++) count += groups[i].words.length
  return count
}

function flatGroup(list) {
  if (list.length === 0) return []
  return [{ sense: "", words: list.map(function(word) { return { word: word, note: "" } }) }]
}

// English stays deliberately light: a few senses per part of speech.
function englishEntries(rows) {
  var result = { pronunciation: "", etymology: "", entries: [] }
  if (!Array.isArray(rows)) return result
  var byPart = {}

  for (var i = 0; i < rows.length; i++) {
    var row = rows[i] || {}
    if (result.pronunciation === "") result.pronunciation = phonetic(row)
    if (result.etymology === "" && row.origin) result.etymology = String(row.origin).trim()

    var meanings = Array.isArray(row.meanings) ? row.meanings : []
    for (var j = 0; j < meanings.length; j++) {
      var part = String(meanings[j].partOfSpeech || "").trim()
      var key = part.toLowerCase()
      if (!byPart[key]) {
        byPart[key] = { part: capitalize(part), info: "", pronunciation: "", senses: [] }
        result.entries.push(byPart[key])
      }
      var entry = byPart[key]
      var definitions = Array.isArray(meanings[j].definitions) ? meanings[j].definitions : []
      for (var k = 0; k < definitions.length && entry.senses.length < MAX_EN_SENSES; k++) {
        var text = String(definitions[k] && definitions[k].definition || "").trim()
        if (text === "") continue
        entry.senses.push({
          label: (entry.senses.length + 1) + ".",
          level: 1,
          text: text,
          example: String(definitions[k].example || "").trim()
        })
      }
    }
  }
  result.entries = result.entries.filter(function(entry) { return entry.senses.length > 0 })
  return result
}

function phonetic(row) {
  var value = String(row.phonetic || "")
  if (value === "" && Array.isArray(row.phonetics)) {
    for (var i = 0; i < row.phonetics.length && value === ""; i++)
      value = String(row.phonetics[i] && row.phonetics[i].text || "")
  }
  return value.replace(/^[\/\[]|[\/\]]$/g, "").trim()
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

// Sections of a French entry that hold neither definitions nor word lists.
var NON_DEFINITION_SECTIONS = {
  "étymologie": true, "prononciation": true, "voir aussi": true, "références": true,
  "anagrammes": true, "homophones": true, "paronymes": true, "traductions": true,
  "notes": true, "dérivés": true, "apparentés": true, "vocabulaire": true,
  "hyperonymes": true, "hyponymes": true, "holonymes": true, "méronymes": true,
  "variantes": true, "variantes orthographiques": true, "diminutifs": true,
  "augmentatifs": true, "phrases": true, "proverbes": true, "faux-amis": true,
  "dérivés autres langues": true, "descendants": true, "attestations": true,
  "quasi-synonymes": true, "synonymes": true, "antonymes": true, "gentilés": true,
  "abréviations": true, "compos": true, "composés": true, "drv": true
}

var PART_NAMES = {
  "nom": "Nom commun", "nom commun": "Nom commun", "adj": "Adjectif", "adv": "Adverbe",
  "verb": "Verbe", "pronom-pers": "Pronom personnel", "prép": "Préposition",
  "conj": "Conjonction", "interj": "Interjection", "art": "Article",
  "loc-nom": "Locution nominale", "loc-verb": "Locution verbale",
  "loc-adj": "Locution adjectivale", "loc-adv": "Locution adverbiale",
  "loc-phr": "Locution-phrase", "nom-pr": "Nom propre"
}

var HEADWORD_INFO = {
  "m": "masculin", "f": "féminin", "n": "neutre", "mf": "masculin et féminin identiques",
  "mf ?": "masculin ou féminin (l’usage hésite)", "fm ?": "féminin ou masculin (l’usage hésite)",
  "invar": "invariable", "sp": "singulier et pluriel identiques", "p": "pluriel",
  "s": "singulier", "plurale tantum": "au pluriel uniquement",
  "t": "transitif", "i": "intransitif", "prnl": "pronominal", "impers": "impersonnel",
  "tr-dir": "transitif direct", "tr-indir": "transitif indirect", "réciproque": "réciproque",
  "dénombrable": "dénombrable", "indénombrable": "indénombrable"
}

// Reads the French section of a fr.wiktionary.org page: every sense of every
// part of speech (with sub-senses and a first example), the grammatical
// information from the headword line, the pronunciation, the etymology, and
// the words listed under `{{S|synonymes}}` / `{{S|antonymes}}`, grouped by the
// sense they apply to and tagged with their usage label (familier, argot…).
// Quasi-synonyms are left out on purpose: they are related words, not
// substitutes.
function wiktionary(wikitext) {
  var lines = joinTemplateLines(String(wikitext || "").split("\n"))
  var inFrench = false
  var section = ""
  var entry = null
  var lastSense = null
  var entries = []
  var etymology = []
  var pronunciation = ""
  var synonymGroups = []
  var antonymGroups = []
  var relationSense = ""
  var counters = [0, 0, 0]

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]

    var language = line.match(/^==\s*\{\{langue\|([^|}]+)/)
    if (language) {
      inFrench = language[1].trim() === "fr"
      section = ""
      entry = null
      continue
    }
    if (!inFrench) continue

    var heading = line.match(/^(===+)\s*\{\{S\|([^}]*)\}\}/)
    if (heading) {
      var params = heading[2].split("|")
      section = params[0].trim()
      if (heading[1].length === 3) entry = null
      lastSense = null
      relationSense = ""
      if (!NON_DEFINITION_SECTIONS[section] && heading[1].length === 3) {
        entry = { part: partName(section, params), info: "", pronunciation: "", senses: [] }
        entries.push(entry)
        counters = [0, 0, 0]
      }
      continue
    }
    if (/^==/.test(line)) {
      section = ""
      entry = null
      continue
    }

    if (section === "étymologie") {
      if (/^:/.test(line)) {
        var origin = cleanWikitext(line.replace(/^:+\s*/, ""))
        if (origin !== "") etymology.push(origin)
      }
      continue
    }

    if (section === "synonymes" || section === "antonymes") {
      var title = relationTitle(line)
      if (title !== null) {
        relationSense = title
        continue
      }
      if (/^\*/.test(line)) readRelationLine(line, relationSense, section === "antonymes" ? antonymGroups : synonymGroups)
      continue
    }

    if (!entry || NON_DEFINITION_SECTIONS[section]) continue

    if (entry.senses.length === 0 && /^'''/.test(line)) {
      readHeadword(line, entry)
      if (pronunciation === "") pronunciation = entry.pronunciation
      continue
    }
    if (entry.pronunciation === "") {
      var inflection = line.match(/^\{\{fr-[^|}]*\|([^|}=]*[^\s|}=][^|}=]*)(?:\||\}\})/)
      if (inflection && /[ɑɛɔøœəʁʃʒɲŋɥ.]/.test(inflection[1])) entry.pronunciation = inflection[1].trim()
    }

    var definition = line.match(/^(#+)(?![*:#])\s*(.*)$/)
    if (definition) {
      lastSense = null
      if (entry.senses.length >= MAX_FR_SENSES) continue
      var level = Math.min(definition[1].length, 3)
      var text = cleanWikitext(definition[2])
      if (text.replace(/\([^)]*\)/g, "").replace(/[\s.;,—-]/g, "") === "" && level === 1) continue
      counters[level - 1]++
      for (var c = level; c < counters.length; c++) counters[c] = 0
      lastSense = { label: senseLabel(level, counters[level - 1]), level: level, text: text, example: "" }
      entry.senses.push(lastSense)
      continue
    }

    var example = line.match(/^#+\*\s*(.*)$/)
    if (example && lastSense && lastSense.example === "") {
      lastSense.example = exampleText(example[1])
    }
  }

  // Drop sub-senses that are only a label and never got an example.
  for (var e = 0; e < entries.length; e++) {
    entries[e].senses = entries[e].senses.filter(function(sense) {
      return sense.example !== "" || sense.text.replace(/\([^)]*\)/g, "").trim() !== ""
    })
  }
  entries = entries.filter(function(item) { return item.senses.length > 0 })
  if (pronunciation === "" && entries.length > 0) pronunciation = entries[0].pronunciation

  return {
    ok: true,
    pronunciation: pronunciation,
    etymology: etymology.join(" "),
    entries: entries,
    synonyms: finishGroups(synonymGroups, MAX_SYNONYMS),
    antonyms: finishGroups(antonymGroups, MAX_ANTONYMS)
  }
}

// Sense headings inside a synonym list: `; ''Prendre un repas (2)''` or the
// title of a `{{(|Bâtiment d’habitation|1}}` box. Returns null for other lines.
function relationTitle(line) {
  var box = line.match(/^\{\{\(\s*(?:\|([^|}]*))?/)
  var heading = line.match(/^;\s*(.*)$/)
  if (!box && !heading) return null
  var text = box ? String(box[1] || "") : heading[1]
  if (/^\s*(?:colonnes|titre)\s*=/.test(text)) text = text.replace(/^\s*titre\s*=/, "")
  if (/^\s*colonnes\s*=/.test(text)) text = ""
  text = cleanWikitext(text).replace(/\s*:\s*$/, "")
  return text.replace(/\((\d+(?:[.,]\d+)*)\)/g, "(sens $1)").trim()
}

// Usage labels shown next to a related word; anything else (often a region
// such as {{France}} or {{Québec}}) is shown as written.
var NOTE_NAMES = {
  "familier": "familier", "fam": "familier", "très familier": "très familier",
  "populaire": "populaire", "argot": "argot", "vulgaire": "vulgaire",
  "littéraire": "littéraire", "soutenu": "soutenu", "vieilli": "vieilli",
  "vieux": "vieux", "désuet": "désuet", "rare": "rare", "péjoratif": "péjoratif",
  "figuré": "figuré", "plaisanterie": "par plaisanterie", "enfantin": "enfantin",
  "néologisme": "néologisme", "archaïsme": "archaïsme", "régionalisme": "régional",
  "anglicisme": "anglicisme", "ironique": "ironique", "injurieux": "injurieux"
}
var IGNORED_NOTES = { "lien": true, "l": true, "réf": true, "R": true, "nobr": true }

// A line can list several words: `* [[appartement]], [[appart]]`.
function readRelationLine(line, sense, groups) {
  var group = null
  for (var g = 0; g < groups.length; g++) if (groups[g].sense === sense) group = groups[g]
  if (!group) {
    group = { sense: sense, words: [] }
    groups.push(group)
  }

  var pieces = line.replace(/^\*+\s*/, "").split(/,(?![^\[{]*[\]}])/)
  for (var i = 0; i < pieces.length; i++) {
    var link = pieces[i].match(/\[\[([^\]|#]+)|\{\{(?:lien|l)\|([^|}]+)/)
    if (!link) continue
    var word = (link[1] || link[2]).trim()
    if (!/[A-Za-zÀ-ÿœŒ]/.test(word) || /:/.test(word)) continue

    var notes = []
    var templates = pieces[i].match(/\{\{[^{}]*\}\}/g) || []
    for (var t = 0; t < templates.length; t++) {
      var name = templates[t].slice(2, -2).split("|")[0].trim()
      if (IGNORED_NOTES[name] || name === "") continue
      notes.push(NOTE_NAMES[name.toLowerCase()] || name)
    }
    var exists = group.words.some(function(item) { return item.word.toLowerCase() === word.toLowerCase() })
    if (!exists) group.words.push({ word: word, note: notes.join(", ") })
  }
}

// Plain words first in each group, then labelled ones; caps the total count.
function finishGroups(groups, max) {
  var total = 0
  var result = []
  for (var i = 0; i < groups.length && total < max; i++) {
    var plain = groups[i].words.filter(function(item) { return item.note === "" })
    var marked = groups[i].words.filter(function(item) { return item.note !== "" })
    var list = plain.concat(marked).slice(0, max - total)
    if (list.length === 0) continue
    total += list.length
    result.push({ sense: groups[i].sense, words: list })
  }
  return result
}

// Multi-line templates such as `{{exemple | lang=fr\n | …}}` are folded onto
// the line that opened them so each definition or example reads as one line.
function joinTemplateLines(lines) {
  var result = []
  var buffer = null
  var depth = 0
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (buffer === null) {
      buffer = line
    } else {
      buffer += " " + line.trim()
    }
    depth += (line.match(/\{\{/g) || []).length - (line.match(/\}\}/g) || []).length
    var openTag = buffer.lastIndexOf("<") > buffer.lastIndexOf(">")
    if ((depth <= 0 && !openTag) || !/^[#:*]/.test(buffer)) {
      result.push(buffer)
      buffer = null
      depth = 0
    }
  }
  if (buffer !== null) result.push(buffer)
  return result
}

function partName(section, params) {
  var name = PART_NAMES[section] || capitalize(section)
  for (var i = 1; i < params.length; i++) {
    if (params[i].trim() === "flexion") return name + " (forme fléchie)"
  }
  return name
}

function readHeadword(line, entry) {
  var info = []
  var pron = line.match(/\{\{pron\|([^|}]*)\|/)
  if (pron && pron[1].trim() !== "") entry.pronunciation = pron[1].trim()

  var templates = line.match(/\{\{[^{}]*\}\}/g) || []
  for (var i = 0; i < templates.length; i++) {
    var pieces = templates[i].slice(2, -2).split("|")
    var name = pieces[0].trim()
    if (HEADWORD_INFO[name]) {
      info.push(HEADWORD_INFO[name])
    } else if (name === "conjugaison") {
      for (var j = 1; j < pieces.length; j++) {
        var group = pieces[j].match(/^\s*(?:groupe|grp)\s*=\s*(\d)/)
        if (group) info.push(group[1] === "1" ? "1er groupe" : group[1] + "e groupe")
      }
    }
  }
  entry.info = info.filter(function(value, index) { return info.indexOf(value) === index }).join(", ")
}

function senseLabel(level, count) {
  if (level === 1) return count + "."
  if (level === 2) return String.fromCharCode(96 + Math.min(count, 26)) + ")"
  return "–"
}

// Wiktionary examples are often long literary quotations; keep them readable
// in the panel by cutting at a word boundary.
function exampleText(text) {
  var s = String(text || "")
  var body = /^\s*\{\{exemple\b/.test(s)
    ? cleanWikitext(s, true)
    : cleanWikitext(s).replace(/^[«"“]\s*|\s*[»"”]$/g, "")
  if (body.length <= MAX_EXAMPLE_LENGTH) return body
  var cut = body.lastIndexOf(" ", MAX_EXAMPLE_LENGTH)
  return body.slice(0, cut > 0 ? cut : MAX_EXAMPLE_LENGTH).replace(/[\s,;:]+$/, "") + " […]"
}

function cleanWikitext(text, keepExample) {
  var s = String(text || "")
  s = s.replace(/<ref[^>]*\/>/g, "").replace(/<ref[^>]*>[\s\S]*?<\/ref>/g, "")
  s = s.replace(/<br\s*\/?>/g, " ").replace(/<[^>]+>/g, "")

  // Links first: their `|` would otherwise split the template around them.
  s = s.replace(/\[\[(?:Image|Fichier|File|Catégorie):[^\]]*\]\]/gi, "")
  s = s.replace(/\[\[[^\]|]*\|([^\]]*)\]\]/g, "$1")
  s = s.replace(/\[\[([^\]]*)\]\]/g, "$1")
  s = s.replace(/\[(?:https?:)?\/\/[^\s\]]+\s+([^\]]*)\]/g, "$1")
  s = s.replace(/\[(?:https?:)?\/\/[^\s\]]+\]/g, "")

  // Expand templates innermost first so nested ones collapse cleanly.
  var previous
  do {
    previous = s
    s = s.replace(/\{\{([^{}]*)\}\}/g, function(match, body) { return template(body, keepExample) })
  } while (s !== previous)

  s = s.replace(/'{2,}/g, "")
  s = s.replace(/\(\s*\)/g, "")
  return s.replace(/\s+/g, " ").replace(/\s+([,.])/g, "$1").trim()
}

var LANGUAGE_NAMES = {
  "la": "latin", "la-cla": "latin classique", "la-mé": "latin médiéval", "la-ecc": "latin ecclésiastique",
  "bas-latin": "bas latin", "fro": "ancien français", "frm": "moyen français", "fr": "français",
  "grc": "grec ancien", "el": "grec", "en": "anglais", "de": "allemand", "it": "italien",
  "es": "espagnol", "pt": "portugais", "nl": "néerlandais", "ar": "arabe", "he": "hébreu",
  "frk": "francique", "gaul": "gaulois", "oc": "occitan", "pro": "ancien occitan",
  "gmh": "moyen haut-allemand", "goh": "vieux haut-allemand", "ang": "vieil anglais",
  "non": "vieux norrois", "ja": "japonais", "zh": "chinois", "ru": "russe", "tr": "turc",
  "fa": "persan", "sa": "sanskrit", "br": "breton", "co": "corse", "ca": "catalan",
  "enm": "moyen anglais", "dum": "moyen néerlandais", "ine-pro": "indo-européen commun"
}

function template(body, keepExample) {
  var pieces = body.split("|")
  var name = pieces[0].trim()
  var positional = []
  var named = {}
  for (var i = 1; i < pieces.length; i++) {
    var pair = pieces[i].match(/^\s*([A-Za-zÀ-ÿ_ -]{1,14}|\d)\s*=\s*([\s\S]*)$/)
    if (pair) named[pair[1].trim()] = pair[2].trim()
    else positional.push(pieces[i].trim())
  }
  var lower = name.toLowerCase()

  if (name === "exemple") return keepExample ? (positional[0] || "") : ""
  if (lower === "note" || lower === "r" || lower === "réf" || lower === "référence nécessaire"
      || lower === "date" && positional.length === 0 || /^ébauche/.test(lower)
      || lower === "réf ?" || lower === "source" || lower === "réf-nécessaire" || /\//.test(name))
    return ""
  if (lower === "date") return "(" + positional[0] + ")"
  if (name === "e" || name === "er" || name === "re" || name === "ers" || name === "es")
    return (positional[0] || "") + name
  if (name === "siècle" || name === "siècle2")
    return positional.length > 0 ? "(" + positional[0].replace(/\?/g, "") + "e siècle)" : ""
  if (name === "term" || name === "term_lien" || name === "sens")
    return positional.length > 0 ? "(" + positional[0] + ")" : ""
  if (name === "lien" || name === "l" || name === "ws" || name === "pc" || name === "smcp"
      || name === "petites capitales" || name === "nobr" || name === "lien web" || name === "lnobr")
    return positional.length > 0 ? positional[0] : (named.titre || "")
  if (name === "w") return positional.length > 1 ? positional[1] : (positional[0] || "")
  if (name === "lang" || name === "langue") return positional.length > 1 ? positional[1] : ""
  if (name === "nom w pc") return positional.join(" ")
  if (name === "cf") return positional.length > 0 ? "→ voir " + positional.join(", ") : "→ voir"
  if (name === "variante de" || name === "variante ortho de" || name === "variante orthographique de")
    return "Variante de " + (positional[0] || "")
  if (name === "étyl" || name === "étylp") {
    var source = LANGUAGE_NAMES[positional[0]] || positional[0] || ""
    var word = named["mot"] || positional[2] || ""
    var meaning = named["sens"] || positional[4] || ""
    return source + (word ? " " + word : "") + (meaning ? " (« " + meaning + " »)" : "")
  }
  if (name === "composé de") {
    var parts = positional.filter(function(piece) { return !/^[a-z]{2,3}$/.test(piece) })
    return "Composé de " + parts.join(" et ")
  }

  // Domain and usage labels such as {{familier|fr}}, {{figuré}} or
  // {{lexique|histoire|religion|fr}}.
  var labels = positional.filter(function(piece) { return !/^[a-z]{2,3}$/.test(piece) })
  if (name === "lexique" || name === "info lex" || name === "domaine") {
    return labels.length > 0 ? "(" + labels.map(capitalize).join(", ") + ")" : ""
  }
  var onlyLanguage = labels.length === 0 && positional.length <= 1
  if (onlyLanguage && /^[a-zàâäçéèêëîïôöûùüÿœ' -]+$/i.test(name) && name.length > 2)
    return "(" + capitalize(name) + ")"
  return ""
}

function capitalize(text) {
  var s = String(text || "")
  return s.charAt(0).toUpperCase() + s.slice(1)
}
