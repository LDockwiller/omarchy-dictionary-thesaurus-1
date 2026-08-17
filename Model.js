.pragma library

function parse(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, error: "The service returned no data." }

  try {
    var payload = JSON.parse(text)
    if (!payload || !Array.isArray(payload.synonyms) || !Array.isArray(payload.antonyms))
      return { ok: false, error: "The service returned an unexpected response." }
    return {
      ok: true,
      definitions: definitions(payload.dictionary),
      synonyms: words(payload.synonyms),
      antonyms: words(payload.antonyms)
    }
  } catch (error) {
    return { ok: false, error: "The service returned unreadable data." }
  }
}

function definitions(entries) {
  if (!Array.isArray(entries)) return []
  var result = []
  var seenParts = {}

  for (var i = 0; i < entries.length && result.length < 3; i++) {
    var meanings = Array.isArray(entries[i].meanings) ? entries[i].meanings : []
    for (var j = 0; j < meanings.length && result.length < 3; j++) {
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
