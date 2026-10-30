/*
 *   SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
 *   SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef CAROUSELCONTAINMENT_H
#define CAROUSELCONTAINMENT_H

#include <Plasma/Containment>

class QQuickItem;

class CarouselContainment : public Plasma::Containment
{
    Q_OBJECT
public:
    explicit CarouselContainment(QObject *parent, const KPluginMetaData &data, const QVariantList &args);

    void init() override;

    // Creates an applet
    Q_INVOKABLE void newTask(const QString &task);

    // cleans all instances of a given applet
    void cleanupTask(const QString &task);

    /**
     * Given an AppletInterface pointer, shows a proper context menu for it
     */
    Q_INVOKABLE void showPlasmoidMenu(QQuickItem *appletInterface, int x, int y);

    /**
     * Same, but x, y are relative to visualParent, which can be in another window
     * (the carousel popup showing a preview of the applet)
     */
    Q_INVOKABLE void showPlasmoidMenuAt(QQuickItem *appletInterface, QQuickItem *visualParent, int x, int y);

    /**
     * Enter edit mode and open the widget explorer, like "Add Widgets…" of the panel
     * the carousel is in: drag widgets from there onto the carousel
     */
    Q_INVOKABLE void showAddWidgets();

    /**
     * Find out global coordinates for a popup given local MouseArea
     * coordinates
     */
    Q_INVOKABLE QPointF popupPosition(QQuickItem *visualParent, int x, int y);

    /**
     * Reparent the item "before" with the same parent as the item "after",
     * then restack it before it, using QQuickITem::stackBefore.
     * used to quickly reorder icons in the systray (or hidden popup)
     * @see QQuickITem::stackBefore
     */
    Q_INVOKABLE void reorderItemBefore(QQuickItem *before, QQuickItem *after);

    /**
     * Reparent the item "after" with the same parent as the item "before",
     * then restack it after it, using QQuickITem::stackAfter.
     * used to quickly reorder icons in the systray (or hidden popup)
     * @see QQuickITem::stackAfter
     */
    Q_INVOKABLE void reorderItemAfter(QQuickItem *after, QQuickItem *before);
};

#endif
