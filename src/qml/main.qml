/*
 *  SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
 *  SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
 *  SPDX-FileCopyrightText: 2026 UW5EG0
 *
 *  SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.draganddrop as DnD

ContainmentItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // panel thickness: the size of the side we can't grow along
    readonly property real thickness: vertical ? width : height
    readonly property real arrowSize: Math.min(thickness, Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing)

    // PlasmoidItems in display order
    property var appletItems: []
    property int currentIndex: -1
    readonly property Item currentItem: currentIndex >= 0 && currentIndex < appletItems.length ? appletItems[currentIndex] : null

    // applet whose full representation is currently shown in the popup
    property Item popupApplet: null
    property Item popupFullItem: null
    // applet with only an inline representation, mirrored as an image in the popup
    property Item popupMirror: null
    // second instance of an inline-only applet's representation, shown in the popup
    property Item popupCopy: null
    property double popupHiddenAt: 0
    // set after startup: applets toggle "expanded" while they initialize
    property bool uiReady: false

    // follow updates bookkeeping
    property bool followReady: false
    property double lastAutoSwitch: 0

    Layout.minimumWidth: vertical ? 0 : layout.implicitWidth
    Layout.preferredWidth: vertical ? -1 : layout.implicitWidth
    Layout.maximumWidth: vertical ? Infinity : layout.implicitWidth
    Layout.minimumHeight: vertical ? layout.implicitHeight : 0
    Layout.preferredHeight: vertical ? layout.implicitHeight : -1
    Layout.maximumHeight: vertical ? layout.implicitHeight : Infinity

    Containment.onAppletAdded: applet => {
        addApplet(applet);
        //when we add an applet, select it straight away
        root.currentIndex = root.appletItems.length - 1;
        saveOrder();
    }
    Containment.onAppletRemoved: applet => {
        let item = root.appletItems.find(item => item.plasmoid.id === applet.id);
        if (!item) {
            // already hidden while its removal could still be undone
            for (let i = 0; i < slot.children.length; i++) {
                const w = slot.children[i];
                if (w.appletItem && w.appletItem.plasmoid.id === applet.id) {
                    item = w.appletItem;
                }
            }
        }
        if (!item) {
            return;
        }
        hideApplet(item);
        delete root.pendingRemoval[applet.id];
        const w = wrapperOf(item);
        if (w) {
            w.destroy();
        }
        saveOrder();
    }

    // applets being removed with an undo possibility: id -> former position
    property var pendingRemoval: ({})

    // take an applet out of the carousel (list, panel and popup); returns its former index
    function hideApplet(appletItem) {
        const items = root.appletItems.slice();
        const idx = items.indexOf(appletItem);
        if (idx < 0) {
            return -1;
        }
        if (appletItem === root.popupApplet) {
            releasePopupItem();
        }
        items.splice(idx, 1);
        let current = root.currentIndex;
        if (idx < current) {
            current--;
        }
        current = items.length === 0 ? -1 : Math.min(Math.max(current, 0), items.length - 1);
        root.appletItems = items;
        if (current !== root.currentIndex) {
            root.currentIndex = current;
        } else if (popup.visible) {
            // same index, different applet
            showInPopup(current >= 0 ? items[current] : null);
        }
        return idx;
    }

    function handleAppletDestroyed(appletItem, destroyed) {
        const id = appletItem.plasmoid.id;
        if (destroyed) {
            const idx = hideApplet(appletItem);
            if (idx >= 0) {
                root.pendingRemoval[id] = idx;
            }
        } else if (id in root.pendingRemoval) {
            // removal undone: put it back where it was
            const items = root.appletItems.slice();
            const idx = Math.min(root.pendingRemoval[id], items.length);
            delete root.pendingRemoval[id];
            const current = root.currentItem;
            items.splice(idx, 0, appletItem);
            root.appletItems = items;
            root.currentIndex = current ? items.indexOf(current) : idx;
            saveOrder();
        }
    }

    onCurrentIndexChanged: {
        // don't use currentItem here: its binding may not be re-evaluated yet
        const item = currentIndex >= 0 && currentIndex < appletItems.length ? appletItems[currentIndex] : null;
        if (item) {
            Plasmoid.configuration.currentAppletId = item.plasmoid.id;
        }
        if (popup.visible) {
            showInPopup(item);
        }
    }

    function prefersFull(appletItem) {
        // explicit only: AppletQuickItem may also keep a hidden full representation parented
        // to itself, so "full.parent === applet" is not a reliable sign of an inline applet
        return appletItem.preferredRepresentation !== null
            && appletItem.preferredRepresentation === appletItem.fullRepresentation;
    }

    // Like the system tray: expanding an applet creates its fullRepresentationItem,
    function showInPopup(appletItem) {
        if (appletItem === root.popupApplet && (root.popupFullItem || root.popupMirror || root.popupCopy)) {
            return;
        }
        releasePopupItem();
        root.popupApplet = appletItem;
        if (!appletItem) {
            return;
        }
        if (prefersFull(appletItem)) {
            // its only representation lives in the panel and one item can't be in two windows:
            // create a second instance of the same component, in the applet's own context, so it
            // binds to the same applet state (crisp and interactive)
            const copy = appletItem.fullRepresentation
                ? appletItem.fullRepresentation.createObject(popupBody)
                : null;
            if (copy) {
                copy.anchors.centerIn = popupBody;
                copy.width = Qt.binding(() => Math.min(popupBody.width, root.copyLength(copy, false)));
                copy.height = Qt.binding(() => Math.min(popupBody.height, root.copyLength(copy, true)));
                root.popupCopy = copy;
                return;
            }
            // fallback: a periodically refreshed image of it
            root.popupMirror = appletItem;
            mirrorTimer.restart();
            refreshMirror();
            return;
        }
        if (!appletItem.expanded) {
            appletItem.expanded = true;
        }
        attachFullItem();
    }

    function attachFullItem() {
        // never take the representation of an inline-only applet out of the panel
        const full = root.popupApplet && !root.popupMirror && !root.popupCopy && !prefersFull(root.popupApplet)
            ? root.popupApplet.fullRepresentationItem : null;
        if (!full || full === root.popupFullItem) {
            return;
        }
        full.anchors.fill = undefined;
        full.anchors.centerIn = undefined;
        full.parent = popupBody;
        full.anchors.fill = popupBody;
        full.visible = true;
        root.popupFullItem = full;
    }

    function releasePopupItem() {
        const applet = root.popupApplet;
        const full = root.popupFullItem;
        root.popupApplet = null;
        root.popupFullItem = null;
        root.popupMirror = null;
        if (root.popupCopy) {
            root.popupCopy.destroy();
            root.popupCopy = null;
        }
        mirrorTimer.stop();
        mirrorImage.source = "";
        if (full) {
            full.anchors.fill = undefined;
            full.parent = popupStorage;
        }
        if (applet && applet.expanded && !prefersFull(applet)) {
            applet.expanded = false;
        }
    }

    // same heuristics as the system tray: a MouseArea covering the representation
    function findMouseArea(item) {
        if (!item) {
            return null;
        }
        if (item instanceof MouseArea) {
            return item;
        }
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (child instanceof MouseArea && child.enabled
                && (child.anchors.fill === item
                    || (child.x === 0 && child.y === 0 && child.width === item.width && child.height === item.height))) {
                return child;
            }
        }
        return null;
    }

    function mirroredMouseArea() {
        const item = root.popupMirror;
        return item ? findMouseArea(item.fullRepresentationItem ?? item.compactRepresentationItem ?? item) : null;
    }

    function forwardClick(mouse) {
        const item = root.popupMirror;
        if (!item) {
            return;
        }
        const mouseArea = mirroredMouseArea();
        if (mouseArea && (mouseArea.acceptedButtons & mouse.button)) {
            mouseArea.clicked(mouse);
        } else if (mouse.button === Qt.LeftButton) {
            item.plasmoid.activated();
        }
        // show the result soon instead of waiting for the next refresh
        mirrorTimer.restart();
    }

    function forwardWheel(wheel) {
        const mouseArea = mirroredMouseArea();
        if (mouseArea) {
            mouseArea.wheel(wheel);
            mirrorTimer.restart();
        }
    }

    // natural size of the popup copy: what it asks for in a panel, at least its implicit size
    function copyLength(item, vertical) {
        const l = item.Layout;
        const pref = vertical ? l.preferredHeight : l.preferredWidth;
        const min = vertical ? l.minimumHeight : l.minimumWidth;
        const implicit = vertical ? item.implicitHeight : item.implicitWidth;
        return Math.max(pref > 0 ? pref : 0, min > 0 ? min : 0, implicit > 0 ? implicit : 0,
                        Kirigami.Units.gridUnit);
    }

    function refreshMirror() {
        const item = root.popupMirror;
        if (!item || item.width <= 0 || item.height <= 0) {
            return;
        }
        item.grabToImage(result => {
            if (item === root.popupMirror) {
                mirrorImage.source = result.url;
            }
        });
    }

    function togglePopup() {
        // the press that closes the popup (window deactivation) also clicks the button
        if (!popup.visible && Date.now() - root.popupHiddenAt < 250) {
            return;
        }
        popup.visible = !popup.visible;
    }

    function addApplet(applet) {
        const appletItem = root.itemFor(applet);

        // StackLayout gives every wrapper (also hidden ones) the slot's geometry, so applets
        // initialize their representation even when not shown, and size changes go through
        // the layout engine instead of a direct binding (timer binds Layout to its own width)
        const wrapper = wrapperComponent.createObject(slot, { "appletItem": appletItem });

        appletItem.anchors.fill = undefined;
        appletItem.parent = wrapper;
        appletItem.anchors.fill = wrapper;
        appletItem.visible = true;

        connectFollow(appletItem);
        appletItem.plasmoid.destroyedChanged.connect(destroyed => root.handleAppletDestroyed(appletItem, destroyed));
        appletItem.expandedChanged.connect(() => {
            // applet opened itself (click on its compact representation)
            if (root.uiReady && appletItem.expanded && !prefersFull(appletItem) && appletItem !== root.popupApplet) {
                const idx = root.appletItems.indexOf(appletItem);
                if (idx >= 0) {
                    root.currentIndex = idx;
                }
                popup.visible = true;
                showInPopup(appletItem);
            }
        });
        appletItem.fullRepresentationItemChanged.connect(() => {
            if (appletItem === root.popupApplet) {
                attachFullItem();
            }
        });

        root.appletItems = root.appletItems.concat([appletItem]);
    }

    // size hint along the panel for the current applet
    function lengthHint(item, which) {
        if (!item) {
            return which === "max" ? Infinity : 0;
        }
        const l = item.Layout;
        const min = root.vertical ? l.minimumHeight : l.minimumWidth;
        const pref = root.vertical ? l.preferredHeight : l.preferredWidth;
        const max = root.vertical ? l.maximumHeight : l.maximumWidth;
        const fill = root.vertical ? l.fillHeight : l.fillWidth;
        if (which === "min") {
            return Math.max(0, min);
        }
        if (which === "max") {
            return max > 0 ? max : Infinity;
        }
        // applets that expect to fill the panel (graphs) get a few thickness units
        let len = pref > 0 ? pref : (fill ? root.thickness * 4 : root.thickness);
        len = Math.max(len, min > 0 ? min : 0);
        if (max > 0 && isFinite(max)) {
            len = Math.min(len, max);
        }
        return Math.round(len);
    }

    function wrapperOf(appletItem) {
        for (let i = 0; i < slot.children.length; i++) {
            if (slot.children[i].appletItem === appletItem) {
                return slot.children[i];
            }
        }
        return null;
    }

    function saveOrder() {
        Plasmoid.configuration.appletOrder = root.appletItems.map(item => String(item.plasmoid.id));
    }

    function moveApplet(from, to) {
        if (from === to || from < 0 || to < 0 || from >= appletItems.length || to >= appletItems.length) {
            return;
        }
        const current = root.currentItem;
        const items = root.appletItems.slice();
        const moved = items.splice(from, 1)[0];
        items.splice(to, 0, moved);
        root.appletItems = items;
        root.currentIndex = items.indexOf(current);
        saveOrder();
    }

    function step(delta) {
        const n = root.appletItems.length;
        if (n === 0) {
            return;
        }
        root.currentIndex = ((root.currentIndex + delta) % n + n) % n;
    }

    function connectFollow(appletItem) {
        const applet = appletItem.plasmoid;
        applet.statusChanged.connect(() => {
            if (Plasmoid.configuration.followStatus
                && (applet.status === PlasmaCore.Types.NeedsAttentionStatus || applet.status === PlasmaCore.Types.ActiveStatus)) {
                followTo(appletItem, "status");
            }
        });
        applet.titleChanged.connect(() => {
            if (Plasmoid.configuration.followTitle) {
                followTo(appletItem, "title");
            }
        });
        applet.iconChanged.connect(() => {
            if (Plasmoid.configuration.followTitle) {
                followTo(appletItem, "icon");
            }
        });
        appletItem.toolTipMainTextChanged.connect(() => {
            if (Plasmoid.configuration.followToolTip) {
                followTo(appletItem, "toolTipMainText");
            }
        });
        appletItem.toolTipSubTextChanged.connect(() => {
            if (Plasmoid.configuration.followToolTip) {
                followTo(appletItem, "toolTipSubText");
            }
        });
    }

    function followTo(appletItem, reason) {
        if (!Plasmoid.configuration.followUpdates || !root.followReady) {
            return;
        }
        const idx = root.appletItems.indexOf(appletItem);
        if (idx < 0 || idx === root.currentIndex) {
            return;
        }
        // don't yank the widget away while the user is looking at or using it
        if (hover.hovered || popup.visible) {
            return;
        }
        const now = Date.now();
        if (now - root.lastAutoSwitch < Plasmoid.configuration.followCooldown * 1000) {
            return;
        }
        root.lastAutoSwitch = now;
        root.currentIndex = idx;
    }

    Component.onCompleted: {
        const applets = Containment.applets;
        for (let i = 0; i < applets.length; i++) {
            addApplet(applets[i]);
        }

        // restore saved order; applets not in the list keep creation order at the end
        const order = Plasmoid.configuration.appletOrder.map(id => parseInt(id));
        const rank = item => {
            const r = order.indexOf(item.plasmoid.id);
            return r < 0 ? order.length : r;
        };
        root.appletItems = root.appletItems.slice().sort((a, b) => rank(a) - rank(b));

        const savedId = Plasmoid.configuration.currentAppletId;
        const savedIdx = root.appletItems.findIndex(item => item.plasmoid.id === savedId);
        root.currentIndex = savedIdx >= 0 ? savedIdx : (root.appletItems.length > 0 ? 0 : -1);
        saveOrder();

        followStartDelay.start();
    }

    Timer {
        id: mirrorTimer
        interval: 1000
        repeat: true
        onTriggered: root.refreshMirror()
    }

    // applets often change status/tooltip while initializing; ignore that
    Timer {
        id: followStartDelay
        interval: 3000
        onTriggered: {
            root.followReady = true;
            root.uiReady = true;
        }
    }

    HoverHandler {
        id: hover
    }

    WheelHandler {
        enabled: Plasmoid.configuration.wheelEnabled && root.appletItems.length > 1
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real accumulated: 0
        onWheel: event => {
            accumulated += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            while (accumulated >= 120) {
                accumulated -= 120;
                root.step(-1);
            }
            while (accumulated <= -120) {
                accumulated += 120;
                root.step(1);
            }
        }
    }

    GridLayout {
        id: layout
        anchors.fill: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: 0
        columnSpacing: 0

        PlasmaComponents.ToolButton {
            visible: root.appletItems.length > 1
            Layout.preferredWidth: root.vertical ? root.thickness : root.arrowSize
            Layout.preferredHeight: root.vertical ? root.arrowSize : root.thickness
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            display: PlasmaComponents.AbstractButton.IconOnly
            padding: 0
            icon.name: root.vertical ? "go-up" : (Application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous")
            text: i18nc("@action:button", "Previous widget")
            onClicked: root.step(-1)
        }

        StackLayout {
            id: slot
            visible: root.currentItem !== null
            // the layout's own index of the wrapper: position in children[] doesn't have to match it
            currentIndex: {
                const w = root.currentItem ? root.wrapperOf(root.currentItem) : null;
                return w ? w.StackLayout.index : -1;
            }

            Layout.minimumWidth: root.vertical ? -1 : root.lengthHint(root.currentItem, "min")
            Layout.preferredWidth: root.vertical ? root.thickness : root.lengthHint(root.currentItem, "pref")
            Layout.maximumWidth: root.vertical ? Infinity : root.lengthHint(root.currentItem, "max")
            Layout.minimumHeight: root.vertical ? root.lengthHint(root.currentItem, "min") : -1
            Layout.preferredHeight: root.vertical ? root.lengthHint(root.currentItem, "pref") : root.thickness
            Layout.maximumHeight: root.vertical ? root.lengthHint(root.currentItem, "max") : Infinity
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
        }

        // shown when the carousel is empty
        Kirigami.Icon {
            visible: root.appletItems.length === 0
            source: Plasmoid.icon
            active: dropArea.containsDrag
            Layout.preferredWidth: root.thickness
            Layout.preferredHeight: root.thickness

            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                mainText: Plasmoid.title
                subText: i18n("Drag widgets here")
            }
        }

        PlasmaComponents.ToolButton {
            visible: root.appletItems.length > 1
            Layout.preferredWidth: root.vertical ? root.thickness : root.arrowSize
            Layout.preferredHeight: root.vertical ? root.arrowSize : root.thickness
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            display: PlasmaComponents.AbstractButton.IconOnly
            padding: 0
            icon.name: root.vertical ? "go-down" : (Application.layoutDirection === Qt.RightToLeft ? "go-previous" : "go-next")
            text: i18nc("@action:button", "Next widget")
            onClicked: root.step(1)
        }

        PlasmaComponents.ToolButton {
            id: expandButton
            visible: root.appletItems.length > 0
            Layout.preferredWidth: root.vertical ? root.thickness : root.arrowSize
            Layout.preferredHeight: root.vertical ? root.arrowSize : root.thickness
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            display: PlasmaComponents.AbstractButton.IconOnly
            padding: 0
            icon.name: "arrow-up"
            checked: popup.visible
            text: i18nc("@action:button", "Show widgets")
            onClicked: root.togglePopup()

            PlasmaComponents.ToolTip {
                text: expandButton.text
            }
        }
    }

    Component {
        id: wrapperComponent

        Item {
            id: wrapper
            property Item appletItem

            // right click on the applet: its own context menu
            MouseArea {
                anchors.fill: parent
                z: 1000
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    const p = mapToItem(wrapper.appletItem, mouse.x, mouse.y);
                    plasmoid.showPlasmoidMenu(wrapper.appletItem, p.x, p.y);
                }
            }
        }
    }

    PlasmaCore.AppletPopup {
        id: popup
        visualParent: root
        appletInterface: root
        popupDirection: switch (Plasmoid.location) {
            case PlasmaCore.Types.TopEdge:
                return Qt.BottomEdge
            case PlasmaCore.Types.LeftEdge:
                return Qt.RightEdge
            case PlasmaCore.Types.RightEdge:
                return Qt.LeftEdge
            default:
                return Qt.TopEdge
        }
        hideOnWindowDeactivate: true

        onVisibleChanged: {
            if (visible) {
                root.showInPopup(root.currentItem);
                popup.requestActivate();
            } else {
                root.popupHiddenAt = Date.now();
                root.releasePopupItem();
            }
        }

        mainItem: RowLayout {
            id: popupLayout
            spacing: Kirigami.Units.smallSpacing

            Keys.onEscapePressed: popup.visible = false

            readonly property Item full: root.popupFullItem
            function hint(full, pref, implicit, fallback) {
                const v = pref > 0 ? pref : implicit;
                return Math.max(fallback, v > 0 ? v : 0);
            }

            OrderList {
                carousel: root
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 11
            }

            Kirigami.Separator {
                Layout.fillHeight: true
            }

            Item {
                id: popupContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 12
                Layout.minimumHeight: Kirigami.Units.gridUnit * 10
                Layout.preferredWidth: popupLayout.full
                    ? popupLayout.hint(popupLayout.full, popupLayout.full.Layout.preferredWidth, popupLayout.full.implicitWidth, Kirigami.Units.gridUnit * 20)
                    : Kirigami.Units.gridUnit * 20
                Layout.preferredHeight: popupLayout.full
                    ? popupLayout.hint(popupLayout.full, popupLayout.full.Layout.preferredHeight, popupLayout.full.implicitHeight, Kirigami.Units.gridUnit * 14)
                    : Kirigami.Units.gridUnit * 14

                // title bar of the shown widget; the "hamburger" opens its context menu
                Rectangle {
                    id: popupBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: barRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                                   Kirigami.Theme.highlightColor.b, 0.25)

                    RowLayout {
                        id: barRow
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            visible: root.popupApplet !== null
                            source: root.popupApplet ? root.popupApplet.plasmoid.icon : ""
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: root.popupApplet ? root.popupApplet.plasmoid.title : ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.ToolButton {
                            id: addButton
                            icon.name: "list-add"
                            display: PlasmaComponents.AbstractButton.IconOnly
                            text: i18nc("@action:button", "Add Widgets…")
                            onClicked: {
                                popup.visible = false;
                                plasmoid.showAddWidgets();
                            }
                            PlasmaComponents.ToolTip {
                                text: addButton.text
                            }
                        }
                        PlasmaComponents.ToolButton {
                            id: removeButton
                            visible: root.popupApplet !== null
                            icon.name: "window-close"
                            display: PlasmaComponents.AbstractButton.IconOnly
                            text: root.popupApplet
                                ? i18nc("@action:button %1 widget name", "Remove %1", root.popupApplet.plasmoid.title)
                                : ""
                            onClicked: {
                                const applet = root.popupApplet;
                                const action = applet ? applet.plasmoid.internalAction("remove") : null;
                                if (action) {
                                    action.trigger();
                                }
                            }
                            PlasmaComponents.ToolTip {
                                text: removeButton.text
                            }
                        }
                        PlasmaComponents.ToolButton {
                            id: menuButton
                            visible: root.popupApplet !== null
                            icon.name: "open-menu-symbolic"
                            display: PlasmaComponents.AbstractButton.IconOnly
                            text: i18nc("@action:button", "Widget menu")
                            onClicked: {
                                if (root.popupApplet) {
                                    plasmoid.showPlasmoidMenuAt(root.popupApplet, menuButton, 0, menuButton.height);
                                }
                            }
                            PlasmaComponents.ToolTip {
                                text: menuButton.text
                            }
                        }
                    }
                }

                Item {
                    id: popupBody
                    anchors.top: popupBar.bottom
                    anchors.topMargin: Kirigami.Units.smallSpacing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    Image {
                        id: mirrorImage
                        anchors.centerIn: parent
                        visible: root.popupMirror !== null
                        // panel-sized image: enlarge up to 2x
                        width: Math.min(parent.width, sourceSize.width * 2)
                        height: Math.min(parent.height, sourceSize.height * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        cache: false

                        // clicks and wheel go to the applet in the panel, as if made there
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => root.forwardClick(mouse)
                            onWheel: wheel => root.forwardWheel(wheel)
                        }
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        visible: !root.popupFullItem && !root.popupMirror && !root.popupCopy
                        text: root.currentItem ? i18n("This widget has no popup view") : i18n("Drag widgets onto the carousel to add them")
                        textFormat: Text.PlainText
                        opacity: 0.7
                    }
                }
            }

            // full representations of collapsed applets wait here, never visible
            Item {
                id: popupStorage
                visible: false
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
            }
        }
    }

    DnD.DropArea {
        id: dropArea
        anchors.fill: parent

        preventStealing: true

        property bool containsDrag: false

        /** Extracts the name of the applet in the drag data if present
         * otherwise returns null*/
        function appletName(event) {
            if (event.mimeData.formats.indexOf("text/x-plasmoidservicename") < 0) {
                return null;
            }
            var plasmoidId = event.mimeData.getDataAsByteArray("text/x-plasmoidservicename");
            return plasmoidId;
        }

        onDragEnter: event => {
            if (!appletName(event)) {
                event.ignore();
                return;
            }
            containsDrag = true;
        }
        onDragLeave: containsDrag = false

        onDrop: event => {
            containsDrag = false;
            var plasmoidId = appletName(event);
            if (!plasmoidId) {
                event.ignore();
                return;
            }
            plasmoid.newTask(plasmoidId);
        }
    }
}
