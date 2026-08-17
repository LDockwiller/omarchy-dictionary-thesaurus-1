import QtQuick
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
  readonly property int panelMaxHeight: Style.space(650)
  readonly property string helperPath: Qt.resolvedUrl("fetch-thesaurus").toString().replace(/^file:\/\//, "")

  property string query: ""
  property string status: "idle"
  property string statusMessage: ""
  property var definitions: []
  property var synonyms: []
  property var antonyms: []
  property string copiedText: ""

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
    root.definitions = []
    root.synonyms = []
    root.antonyms = []
    root.copiedText = ""
  }

  function runLookup() {
    var q = String(searchField.text || "").trim()
    if (q === "") return
    if (lookupProc.running) lookupProc.running = false
    root.query = q
    root.status = "loading"
    root.statusMessage = ""
    root.definitions = []
    root.synonyms = []
    root.antonyms = []
    root.copiedText = ""
    lookupProc.command = [root.helperPath, q]
    lookupProc.running = true
  }

  function useResult(word) {
    search(String(word || ""))
  }

  function copyResults() {
    var pieces = []
    if (root.definitions.length > 0) {
      var definitionText = []
      for (var i = 0; i < root.definitions.length; i++) definitionText.push(root.definitions[i].text)
      pieces.push("Definitions of " + root.query + ": " + definitionText.join("; "))
    }
    if (root.synonyms.length > 0) pieces.push("Synonyms for " + root.query + ": " + root.synonyms.join(", "))
    if (root.antonyms.length > 0) pieces.push("Antonyms for " + root.query + ": " + root.antonyms.join(", "))
    var output = pieces.join("\n")
    if (output === "") return
    Quickshell.execDetached(["wl-copy", output])
    root.copiedText = "Copied"
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
        root.statusMessage = "Could not reach the word services. Check your connection and try again."
        return
      }
      var result = Model.parse(lookupOutput.text)
      if (!result.ok) {
        root.status = "error"
        root.statusMessage = result.error
        return
      }
      root.definitions = result.definitions
      root.synonyms = result.synonyms
      root.antonyms = result.antonyms
      root.status = (root.definitions.length === 0 && root.synonyms.length === 0 && root.antonyms.length === 0) ? "empty" : "ok"
    }
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedText = ""
  }

  onOpenedChanged: if (opened) refreshFocus()

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

      Column {
        id: panelColumn
        width: parent.width
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
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Dictionary & Thesaurus"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              width: parent.width
              text: root.status === "loading" ? "SEARCHING…" : "DEFINITIONS · SYNONYMS · ANTONYMS"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
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
                placeholderText: "Enter a word…"
                placeholderTextColor: Qt.darker(root.contentForeground, 2.0)
                background: null
                selectByMouse: true
                clip: true
                onAccepted: root.runLookup()
                onTextChanged: {
                  if (String(text || "").trim() === "") root.clearResults()
                  else if (root.status !== "loading" && String(text || "").trim() !== root.query) {
                    root.status = "idle"
                    root.definitions = []
                    root.synonyms = []
                    root.antonyms = []
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
            text: "Type a word and press Enter. Click any result to explore that word."
            color: Qt.darker(root.contentForeground, 1.3)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "Powered by Free Dictionary API and Datamuse — no account or API key required."
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
            text: "Finding words related to “" + root.query + "”…"
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
            text: root.status === "empty" ? "No matches found for “" + root.query + "”." : "Something went wrong."
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

            Text {
              width: parent.width - copyButton.width
              text: root.query
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.display
              font.bold: true
              elide: Text.ElideRight
            }

            Button {
              id: copyButton
              text: root.copiedText === "" ? "Copy all" : root.copiedText
              foreground: root.contentForeground
              onClicked: root.copyResults()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(7)

            Text {
              text: "DEFINITIONS  " + root.definitions.length
              color: Qt.darker(root.contentForeground, 1.35)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.0
            }

            Repeater {
              model: root.definitions

              Row {
                required property var modelData
                required property int index
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: Style.space(22)
                  text: (index + 1) + "."
                  color: Color.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  width: parent.width - Style.space(30)
                  text: (modelData.part === "" ? "" : modelData.part + " · ") + modelData.text
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }
              }
            }

            Text {
              visible: root.definitions.length === 0
              text: "No definition found."
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
              text: "SYNONYMS  " + root.synonyms.length
              color: Qt.darker(root.contentForeground, 1.35)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.0
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.synonyms
                Button {
                  required property string modelData
                  text: modelData
                  foreground: root.contentForeground
                  onClicked: root.useResult(modelData)
                }
              }
            }

            Text {
              visible: root.synonyms.length === 0
              text: "No direct synonyms found."
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
              text: "ANTONYMS  " + root.antonyms.length
              color: Qt.darker(root.contentForeground, 1.35)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.0
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.antonyms
                Button {
                  required property string modelData
                  text: modelData
                  foreground: root.contentForeground
                  onClicked: root.useResult(modelData)
                }
              }
            }

            Text {
              visible: root.antonyms.length === 0
              text: "No direct antonyms found."
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
