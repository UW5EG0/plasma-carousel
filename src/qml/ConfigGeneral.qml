/*
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_wheelEnabled: wheelCheck.checked
    property alias cfg_followUpdates: followCheck.checked
    property alias cfg_followStatus: statusCheck.checked
    property alias cfg_followTitle: titleCheck.checked
    property alias cfg_followToolTip: toolTipCheck.checked
    property alias cfg_followCooldown: cooldownSpin.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: wheelCheck
            Kirigami.FormData.label: i18nc("@title:label", "Mouse wheel:")
            text: i18nc("@option:check", "Switch widgets with the mouse wheel")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: followCheck
            Kirigami.FormData.label: i18nc("@title:label", "Follow updates:")
            text: i18nc("@option:check", "Switch to a widget when it changes")
        }
        QQC2.CheckBox {
            id: statusCheck
            enabled: followCheck.checked
            text: i18nc("@option:check", "Status changed (needs attention / active)")
        }
        QQC2.CheckBox {
            id: titleCheck
            enabled: followCheck.checked
            text: i18nc("@option:check", "Title or icon changed")
        }
        QQC2.CheckBox {
            id: toolTipCheck
            enabled: followCheck.checked
            text: i18nc("@option:check", "Tooltip text changed")
        }
        QQC2.SpinBox {
            id: cooldownSpin
            enabled: followCheck.checked
            Kirigami.FormData.label: i18nc("@label:spinbox", "Minimum pause between switches:")
            from: 0
            to: 600
            textFromValue: (value, locale) => i18ncp("@item:valuesuffix", "%1 second", "%1 seconds", value)
            valueFromText: (text, locale) => parseInt(text)
        }
    }
}
