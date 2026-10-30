/*
 *  SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
 *  SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// Expander of the contained applets. Like the system tray's one it has no popup of its own:
// main.qml catches the applet's "expanded" and shows its fullRepresentationItem in the carousel popup.
PlasmaCore.ToolTipArea {
    id: appletRoot
    objectName: "org.kde.desktop-CompactApplet"
    anchors.fill: parent

    mainText: plasmoidItem?.toolTipMainText ?? ""
    subText: plasmoidItem?.toolTipSubText ?? ""
    location: Plasmoid.location
    active: plasmoidItem ? !plasmoidItem.expanded : false
    textFormat: plasmoidItem?.toolTipTextFormat ?? Text.AutoText
    mainItem: plasmoidItem?.toolTipItem ?? null

    property Item fullRepresentation
    property Item compactRepresentation
    property PlasmoidItem plasmoidItem

    Connections {
        target: Plasmoid
        function onContextualActionsAboutToShow() {
            appletRoot.hideImmediately()
        }
    }

    onCompactRepresentationChanged: {
        if (compactRepresentation) {
            compactRepresentation.parent = appletRoot;
            compactRepresentation.anchors.fill = appletRoot;
            compactRepresentation.visible = true;
        }
        appletRoot.visible = true;
    }
}
