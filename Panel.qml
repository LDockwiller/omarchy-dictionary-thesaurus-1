import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "dlpwaters.thesaurus"
  ipcTarget: "dlpwaters.thesaurus"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int panelWidth: Style.space(420)
  readonly property int panelMaxHeight: Style.space(760)
  readonly property string helperPath: Qt.resolvedUrl("fetch-thesaurus").toString().replace(/^file:\/\//, "")

  property string language: "en"
  property string query: ""
  property string status: "idle"
  property string statusMessage: ""
  property var entries: []
  property string pronunciation: ""
  property string etymology: ""
  property var synonyms: []
  property var antonyms: []
  property string copiedText: ""

  readonly property var strings: ({
    en: {
      title: "Dictionary & Thesaurus",
      subtitle: "DEFINITIONS · SYNONYMS · ANTONYMS",
      searching: "SEARCHING…",
      placeholder: "Enter a word…",
      hint: "Type a word and press Enter. Click any result to explore that word.",
      credits: "Powered by Free Dictionary API and Datamuse — no account or API key required.",
      loading: "Finding words related to “%1”…",
      empty: "No matches found for “%1”.",
      failed: "Something went wrong.",
      network: "Could not reach the word services. Check your connection and try again.",
      noData: "The service returned no data.",
      unexpected: "The service returned an unexpected response.",
      unreadable: "The service returned unreadable data.",
      copyAll: "Copy all",
      copied: "Copied",
      definitions: "DEFINITIONS",
      etymology: "ORIGIN",
      synonyms: "SYNONYMS",
      antonyms: "ANTONYMS",
      noDefinitions: "No definition found.",
      noSynonyms: "No direct synonyms found.",
      noAntonyms: "No direct antonyms found."
    },
    fr: {
      title: "Dictionnaire & synonymes",
      subtitle: "DÉFINITIONS · SYNONYMES · ANTONYMES",
      searching: "RECHERCHE…",
      placeholder: "Saisissez un mot…",
      hint: "Tapez un mot et appuyez sur Entrée. Cliquez sur un résultat pour explorer ce mot.",
      credits: "Données du Wiktionnaire — sans compte ni clé d’API.",
      loading: "Recherche de mots liés à « %1 »…",
      empty: "Aucun résultat pour « %1 ».",
      failed: "Une erreur est survenue.",
      network: "Impossible de joindre le Wiktionnaire. Vérifiez votre connexion et réessayez.",
      noData: "Le service n’a renvoyé aucune donnée.",
      unexpected: "Le service a renvoyé une réponse inattendue.",
      unreadable: "Le service a renvoyé des données illisibles.",
      copyAll: "Tout copier",
      copied: "Copié",
      definitions: "DÉFINITIONS",
      etymology: "ÉTYMOLOGIE",
      synonyms: "SYNONYMES",
      antonyms: "ANTONYMES",
      noDefinitions: "Aucune définition trouvée.",
      noSynonyms: "Aucun synonyme trouvé.",
      noAntonyms: "Aucun antonyme trouvé."
    }
  })

  function t(key) {
    var table = root.strings[root.language] || root.strings.en
    return table[key] !== undefined ? table[key] : root.strings.en[key]
  }

  function setLanguage(language) {
    if (applyLanguage(language) && root.query !== "" && String(searchField.text || "").trim() === root.query)
      runLookup()
  }

  // Switches the lookup language and remembers it in this widget's shell.json entry.
  function applyLanguage(language) {
    var next = language === "fr" ? "fr" : "en"
    if (next === root.language) return false
    root.language = next

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.language = next
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    return true
  }

  function open() {
    root.controller.show()
    refreshFocus()
  }

  function close() {
    if (lookupProc.running) lookupProc.running = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refreshFocus() {
    if (!root.opened) return
    Qt.callLater(function() {
      searchField.forceActiveFocus()
      if (searchField.text.length > 0) searchField.selectAll()
    })
  }

  function searchIn(word, language) {
    applyLanguage(language)
    search(word)
  }

  function search(word) {
    var q = String(word || "").trim()
    searchField.text = q
    if (q === "") {
      clearResults()
      return
    }
    runLookup()
  }

  function clearResults() {
    if (lookupProc.running) lookupProc.running = false
    root.query = ""
    root.status = "idle"
    root.statusMessage = ""
    root.resetResults()
    root.copiedText = ""
  }

  function resetResults() {
    root.entries = []
    root.pronunciation = ""
    root.etymology = ""
    root.synonyms = []
    root.antonyms = []
    panelFlick.contentY = 0
  }

  function runLookup() {
    var q = String(searchField.text || "").trim()
    if (q === "") return
    if (lookupProc.running) lookupProc.running = false
    root.query = q
    root.status = "loading"
    root.statusMessage = ""
    root.resetResults()
    root.copiedText = ""
    lookupProc.command = [root.helperPath, q, root.language]
    lookupProc.running = true
  }

  function useResult(word) {
    search(String(word || ""))
  }

  function copyResults() {
    if (root.status !== "ok") return
    var output = Model.plainText({
      pronunciation: root.pronunciation,
      etymology: root.etymology,
      entries: root.entries,
      synonyms: root.synonyms,
      antonyms: root.antonyms
    }, root.query, { etymology: t("etymology"), synonyms: t("synonyms"), antonyms: t("antonyms") })
    Quickshell.execDetached(["wl-copy", output])
    root.copiedText = t("copied")
    copiedTimer.restart()
  }

  Process {
    id: lookupProc
    stdout: StdioCollector { id: lookupOutput; waitForEnd: true }
    stderr: StdioCollector { id: lookupError; waitForEnd: true }
    onExited: function(exitCode) {
      if (root.status !== "loading") return
      if (exitCode !== 0) {
        root.status = "error"
        root.statusMessage = t("network")
        return
      }
      var result = Model.parse(lookupOutput.text)
      if (!result.ok) {
        root.status = "error"
        root.statusMessage = t(result.error)
        return
      }
      root.entries = result.entries
      root.pronunciation = result.pronunciation
      root.etymology = result.etymology
      root.synonyms = result.synonyms
      root.antonyms = result.antonyms
      root.status = (root.entries.length === 0 && root.synonyms.length === 0 && root.antonyms.length === 0) ? "empty" : "ok"
    }
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedText = ""
  }

  onOpenedChanged: if (opened) refreshFocus()
  onSettingsChanged: root.language = root.setting("language", root.language) === "fr" ? "fr" : "en"

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.panelWidth)
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, root.panelMaxHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

        Column {
          id: panelColumn
          width: panelFlick.width - (panelFlick.contentHeight > panelFlick.height ? Style.space(10) : 0)
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              text: "󰂺"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: languageGroup.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.t("title")
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                width: parent.width
                text: root.status === "loading" ? root.t("searching") : root.t("subtitle")
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }

            ButtonGroup {
              id: languageGroup
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)
              focusable: false
              options: ["EN", "FR"]
              value: root.language.toUpperCase()
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              onChanged: function(value) {
                root.setLanguage(value.toLowerCase())
                root.refreshFocus()
              }
            }
          }

          PanelSeparator { foreground: root.contentForeground }

          Item {
            width: parent.width
            implicitHeight: Style.space(46)

            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: "transparent"
              border.width: Style.spacing.hairline
              border.color: searchField.activeFocus ? Color.accent : Qt.darker(root.contentForeground, 1.7)

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(8)

                Text {
                  text: "󰍉"
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.title
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(22)
                  horizontalAlignment: Text.AlignHCenter
                }

                TextField {
                  id: searchField
                  width: parent.width - actions.width - Style.space(30)
                  height: parent.height
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  placeholderText: root.t("placeholder")
                  placeholderTextColor: Qt.darker(root.contentForeground, 2.0)
                  background: null
                  selectByMouse: true
                  clip: true
                  onAccepted: root.runLookup()
                  onTextChanged: {
                    if (String(text || "").trim() === "") root.clearResults()
                    else if (root.status !== "loading" && String(text || "").trim() !== root.query) {
                      root.status = "idle"
                      root.resetResults()
                    }
                  }
                  Keys.onEscapePressed: function(event) {
                    if (searchField.text !== "") searchField.text = ""
                    else root.close()
                    event.accepted = true
                  }
                }

                Row {
                  id: actions
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Button {
                    visible: searchField.text !== ""
                    text: "✕"
                    foreground: root.contentForeground
                    onClicked: {
                      searchField.text = ""
                      root.refreshFocus()
                    }
                  }

                  Button {
                    text: "→"
                    foreground: root.contentForeground
                    enabled: String(searchField.text || "").trim() !== "" && root.status !== "loading"
                    onClicked: root.runLookup()
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.contentForeground }

          Column {
            width: parent.width
            visible: root.status === "idle"
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: root.t("hint")
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              text: root.t("credits")
              color: Qt.darker(root.contentForeground, 1.7)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Row {
            visible: root.status === "loading"
            spacing: Style.space(10)

            Text {
              text: "󰍉"
              color: Color.accent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              NumberAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.status === "loading" }
            }

            Text {
              text: root.t("loading").arg(root.query)
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
          }

          Column {
            width: parent.width
            visible: root.status === "error" || root.status === "empty"
            spacing: Style.space(4)

            Text {
              width: parent.width
              text: root.status === "empty" ? root.t("empty").arg(root.query) : root.t("failed")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: root.statusMessage !== ""
              text: root.statusMessage
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            visible: root.status === "ok"
            spacing: Style.space(14)

            Row {
              width: parent.width

              Column {
                width: parent.width - copyButton.width
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: root.query
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: root.pronunciation !== ""
                  text: root.language === "fr" ? "\\" + root.pronunciation + "\\" : "/" + root.pronunciation + "/"
                  color: Qt.darker(root.contentForeground, 1.35)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
              }

              Button {
                id: copyButton
                text: root.copiedText === "" ? root.t("copyAll") : root.copiedText
                foreground: root.contentForeground
                onClicked: root.copyResults()
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(7)

              Text {
                text: root.t("definitions") + "  " + Model.senseCount(root.entries)
                color: Qt.darker(root.contentForeground, 1.35)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
              }

              // One block per part of speech: heading, grammatical details,
              // then numbered senses with sub-senses and an example each.
              Repeater {
                model: root.entries

                Column {
                  id: entryBlock
                  required property var modelData
                  required property int index
                  width: parent.width
                  spacing: Style.space(6)
                  topPadding: index === 0 ? 0 : Style.space(8)

                  Text {
                    width: parent.width
                    text: entryBlock.modelData.part
                      + (entryBlock.modelData.info !== "" ? "  ·  " + entryBlock.modelData.info : "")
                      + (entryBlock.modelData.pronunciation !== "" && entryBlock.modelData.pronunciation !== root.pronunciation
                         ? "  ·  \\" + entryBlock.modelData.pronunciation + "\\" : "")
                    color: Color.accent
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    wrapMode: Text.WordWrap
                  }

                  Repeater {
                    model: entryBlock.modelData.senses

                    Row {
                      id: senseRow
                      required property var modelData
                      readonly property int indent: (modelData.level - 1) * Style.space(22)
                      width: parent.width
                      spacing: Style.space(8)

                      Item { width: senseRow.indent; height: 1 }

                      Text {
                        width: Style.space(24)
                        text: senseRow.modelData.label
                        color: senseRow.modelData.level === 1 ? Color.accent : Qt.darker(root.contentForeground, 1.3)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: senseRow.modelData.level === 1
                      }

                      Column {
                        width: senseRow.width - senseRow.indent - Style.space(24) - senseRow.spacing * 2
                        spacing: Style.space(3)

                        Text {
                          width: parent.width
                          text: senseRow.modelData.text
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.body
                          wrapMode: Text.WordWrap
                        }

                        Text {
                          width: parent.width
                          visible: senseRow.modelData.example !== ""
                          text: root.language === "fr" ? "« " + senseRow.modelData.example + " »" : "“" + senseRow.modelData.example + "”"
                          color: Qt.darker(root.contentForeground, 1.45)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.italic: true
                          wrapMode: Text.WordWrap
                        }
                      }
                    }
                  }
                }
              }

              Text {
                visible: root.entries.length === 0
                text: root.t("noDefinitions")
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }
            }

            PanelSeparator {
              visible: root.etymology !== ""
              foreground: root.contentForeground
            }

            Column {
              width: parent.width
              visible: root.etymology !== ""
              spacing: Style.space(7)

              Text {
                text: root.t("etymology")
                color: Qt.darker(root.contentForeground, 1.35)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
              }

              Text {
                width: parent.width
                text: root.etymology
                color: Qt.darker(root.contentForeground, 1.15)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            PanelSeparator { foreground: root.contentForeground }

            Column {
              width: parent.width
              spacing: Style.space(7)

              Text {
                text: root.t("synonyms") + "  " + Model.wordCount(root.synonyms)
                color: Qt.darker(root.contentForeground, 1.35)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
              }

              RelationList {
                width: parent.width
                groups: root.synonyms
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onPicked: function(word) { root.useResult(word) }
              }

              Text {
                visible: root.synonyms.length === 0
                text: root.t("noSynonyms")
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }
            }

            PanelSeparator { foreground: root.contentForeground }

            Column {
              width: parent.width
              spacing: Style.space(7)

              Text {
                text: root.t("antonyms") + "  " + Model.wordCount(root.antonyms)
                color: Qt.darker(root.contentForeground, 1.35)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
              }

              RelationList {
                width: parent.width
                groups: root.antonyms
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onPicked: function(word) { root.useResult(word) }
              }

              Text {
                visible: root.antonyms.length === 0
                text: root.t("noAntonyms")
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }
            }
          }
        }
      }
    }
  }
}
