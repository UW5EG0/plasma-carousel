add_definitions(-DTRANSLATION_DOMAIN=\"plasma_applet_org.uw5eg0.carousel.container\")

plasma_add_applet(org.uw5eg0.carousel.container
    QML_SOURCES
        qml/CompactApplet.qml
        qml/config.qml
        qml/main.qml
        qml/OrderList.qml
        qml/ConfigGeneral.qml
    CPP_SOURCES
        carouselcontainment.cpp
    RESOURCES
        main.xml
)
target_link_libraries(org.uw5eg0.carousel.container PRIVATE
    Qt::Gui
    Qt::Quick
    Qt::Widgets
    Plasma::Plasma
    KF6::I18n
    KF6::ConfigCore
)
