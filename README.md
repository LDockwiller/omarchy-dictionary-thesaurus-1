# Dictionary & Thesaurus for Omarchy

A compact Omarchy Quattro bar plugin for finding English and French
definitions, synonyms, and antonyms through free, keyless APIs.

Fork of [dlpwaters/omarchy-dictionary-thesaurus](https://github.com/dlpwaters/omarchy-dictionary-thesaurus)
with French support.

## Features

- **English**: definitions and parts of speech from the Free Dictionary API,
  synonyms and antonyms from Datamuse
- **French**: complete entries from the French Wiktionary (fr.wiktionary.org):
  - every sense of every part of speech, including sub-senses
  - usage and domain labels (figuré, familier, cuisine, marine…)
  - an example sentence for each sense
  - gender, number, transitivity, and verb group from the headword line
  - pronunciation (API) and etymology
  - synonyms and antonyms grouped by sense, with usage labels (familier,
    argot, regional…) and the plain words listed first
- Scrollable results panel
- EN / FR switch in the panel; the interface follows the selected language and
  the last choice is remembered
- Clickable related words for quick follow-up searches
- One-click copying of the visible results
- No account, API key, local database, or background service

## Install

```bash
omarchy plugin add https://github.com/LDockwiller/omarchy-dictionary-thesaurus-1.git
omarchy plugin enable dlpwaters.thesaurus
```

The plugin appears as a book icon in the Omarchy bar. Click it, pick EN or FR,
type a word, and press Enter. Click any synonym or antonym to look it up.

## Language

The EN / FR buttons in the panel header switch the lookup language. The choice
is saved in the widget's entry in `~/.config/omarchy/shell.json`, which you can
also set by hand:

```json
{ "id": "dlpwaters.thesaurus", "language": "fr" }
```

It can also be driven over IPC:

```bash
qs ipc -p /usr/share/omarchy/shell call dlpwaters.thesaurus searchIn "heureux" fr
qs ipc -p /usr/share/omarchy/shell call dlpwaters.thesaurus setLanguage en
```

## Remove

```bash
omarchy plugin remove dlpwaters.thesaurus
```

## Network and privacy

The plugin stores no search history or other user data. It contacts
`api.dictionaryapi.dev` and `api.datamuse.com` (English) or `fr.wiktionary.org`
(French) only after a search is submitted. Search terms are sent to those
services as part of their HTTPS request URLs.

## Requirements

- Omarchy Quattro with `omarchy-shell`
- `curl` and `jq`
- Internet access for lookups

## License

[MIT](LICENSE)
