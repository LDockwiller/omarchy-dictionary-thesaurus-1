# Dictionary & Thesaurus for Omarchy

A compact Omarchy Quattro bar plugin for finding English definitions, synonyms,
and antonyms through free, keyless APIs.

## Features

- Definitions and parts of speech from the Free Dictionary API
- Synonyms and antonyms from Datamuse
- Clickable related words for quick follow-up searches
- One-click copying of the visible results
- No account, API key, local database, or background service

## Install

```bash
omarchy plugin add https://github.com/dlpwaters/omarchy-dictionary-thesaurus.git
omarchy plugin enable dlpwaters.thesaurus
```

The plugin appears as a book icon in the Omarchy bar. Click it, type a word,
and press Enter. Click any synonym or antonym to look it up.

## Remove

```bash
omarchy plugin remove dlpwaters.thesaurus
```

## Network and privacy

The plugin stores no search history or other user data. It contacts
`api.dictionaryapi.dev` and `api.datamuse.com` only after a search is submitted.
Search terms are sent to those services as part of their HTTPS request URLs.

## Requirements

- Omarchy Quattro with `omarchy-shell`
- `curl`
- Internet access for lookups

## License

[MIT](LICENSE)
