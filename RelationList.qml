import QtQuick
import qs.Commons
import qs.Ui

// Related words grouped by the sense they apply to; usage labels such as
// "familier" or a region are shown after the word.
Column {
  id: root

  property var groups: []
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal picked(string word)

  spacing: Style.space(8)

  Repeater {
    model: root.groups

    Column {
      id: relationGroup
      required property var modelData
      width: root.width
      spacing: Style.space(4)

      Text {
        width: parent.width
        visible: relationGroup.modelData.sense !== ""
        text: relationGroup.modelData.sense
        color: Qt.darker(root.foreground, 1.25)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.italic: true
        wrapMode: Text.WordWrap
      }

      Flow {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: relationGroup.modelData.words
          Button {
            required property var modelData
            text: modelData.word + (modelData.note !== "" ? "  · " + modelData.note : "")
            foreground: root.foreground
            onClicked: root.picked(modelData.word)
          }
        }
      }
    }
  }
}
