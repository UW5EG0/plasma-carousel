/*
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// popup list of the carousel's widgets: click selects, arrows reorder
ColumnLayout {
    id: list

    required property Item carousel


    focus: true
    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: i18nc("@title", "Widgets")
        textFormat: Text.PlainText
        font.bold: true
    }

    PlasmaComponents.Label {
        visible: list.carousel.appletItems.length === 0
        text: i18n("Drag widgets onto the carousel to add them")
        textFormat: Text.PlainText
    }

    Repeater {
        model: list.carousel.appletItems

        delegate: RowLayout {
            id: row

            required property Item modelData
            required property int index

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ItemDelegate {
                Layout.fillWidth: true
                highlighted: row.index === list.carousel.currentIndex
                icon.name: row.modelData.plasmoid.icon
                text: row.modelData.plasmoid.title
                onClicked: list.carousel.currentIndex = row.index
            }
            PlasmaComponents.ToolButton {
                icon.name: "go-up"
                enabled: row.index > 0
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18nc("@action:button", "Move up")
                onClicked: list.carousel.moveApplet(row.index, row.index - 1)
            }
            PlasmaComponents.ToolButton {
                icon.name: "go-down"
                enabled: row.index < list.carousel.appletItems.length - 1
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18nc("@action:button", "Move down")
                onClicked: list.carousel.moveApplet(row.index, row.index + 1)
            }
            PlasmaComponents.ToolButton {
                icon.name: "edit-delete-remove"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18nc("@action:button", "Remove widget")
                onClicked: row.modelData.plasmoid.internalAction("remove").trigger()
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
