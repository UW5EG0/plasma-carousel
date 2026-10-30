/*
 *   SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
 *   SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "carouselcontainment.h"

#include <QAction>
#include <QDebug>
#include <QMenu>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>

#include <Plasma/Corona>

CarouselContainment::CarouselContainment(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : Plasma::Containment(parent, data, args)
{
    setHasConfigurationInterface(true);
}

void CarouselContainment::init()
{
    Plasma::Containment::init();
}

void CarouselContainment::newTask(const QString &task)
{
    createApplet(task, QVariantList{QStringLiteral("org.kde.plasma:force-create")});
}

void CarouselContainment::cleanupTask(const QString &task)
{
    const auto appletList = applets();
    for (Plasma::Applet *applet : appletList) {
        if (!applet->pluginMetaData().isValid() || task == applet->pluginMetaData().pluginId()) {
            applet->destroy();
        }
    }
}

void CarouselContainment::showPlasmoidMenu(QQuickItem *appletInterface, int x, int y)
{
    showPlasmoidMenuAt(appletInterface, appletInterface, x, y);
}

void CarouselContainment::showPlasmoidMenuAt(QQuickItem *appletInterface, QQuickItem *visualParent, int x, int y)
{
    if (!appletInterface || !visualParent) {
        return;
    }

    Plasma::Applet *applet = appletInterface->property("_plasma_applet").value<Plasma::Applet *>();
    if (!applet) {
        return;
    }

    QPointF pos = visualParent->mapToScene(QPointF(x, y));

    if (visualParent->window() && visualParent->window()->screen()) {
        pos = visualParent->window()->mapToGlobal(pos.toPoint());
    } else {
        pos = QPoint();
    }

    QMenu *desktopMenu = new QMenu;
    connect(this, &QObject::destroyed, desktopMenu, &QMenu::close);
    desktopMenu->setAttribute(Qt::WA_DeleteOnClose);

    Q_EMIT applet->contextualActionsAboutToShow();
    const QList<QAction *> actions = applet->contextualActions();
    for (QAction *action : actions) {
        if (action) {
            desktopMenu->addAction(action);
        }
    }

    // add run associated action/ remove / alternatives
    desktopMenu->addActions(applet->internalActions());

    if (desktopMenu->isEmpty()) {
        delete desktopMenu;
        return;
    }

    desktopMenu->adjustSize();

    if (QScreen *screen = visualParent->window() ? visualParent->window()->screen() : nullptr) {
        const QRect geo = screen->availableGeometry();

        pos =
            QPoint(qBound(geo.left(), (int)pos.x(), geo.right() - desktopMenu->width()), qBound(geo.top(), (int)pos.y(), geo.bottom() - desktopMenu->height()));
    }

    desktopMenu->popup(pos.toPoint());
}

void CarouselContainment::showAddWidgets()
{
    // for a CustomEmbedded containment this is the panel we are in; the shell connects only
    // top level containments' showAddWidgetsInterface, so use the panel's action
    Plasma::Containment *parentContainment = containment();
    if (!parentContainment || parentContainment == this) {
        return;
    }
    if (QAction *action = parentContainment->internalAction(QStringLiteral("add widgets"))) {
        action->trigger();
    }
}

QPointF CarouselContainment::popupPosition(QQuickItem *visualParent, int x, int y)
{
    if (!visualParent) {
        return QPointF(0, 0);
    }

    QPointF pos = visualParent->mapToScene(QPointF(x, y));

    if (visualParent->window() && visualParent->window()->screen()) {
        pos = visualParent->window()->mapToGlobal(pos.toPoint());
    } else {
        return QPoint();
    }
    return pos;
}

void CarouselContainment::reorderItemBefore(QQuickItem *before, QQuickItem *after)
{
    if (!before || !after) {
        return;
    }

    before->setVisible(false);
    before->setParentItem(after->parentItem());
    before->stackBefore(after);
    before->setVisible(true);
}

void CarouselContainment::reorderItemAfter(QQuickItem *after, QQuickItem *before)
{
    if (!before || !after) {
        return;
    }

    after->setVisible(false);
    after->setParentItem(before->parentItem());
    after->stackAfter(before);
    after->setVisible(true);
}

K_PLUGIN_CLASS_WITH_JSON(CarouselContainment, "metadata.json")

#include "carouselcontainment.moc"
