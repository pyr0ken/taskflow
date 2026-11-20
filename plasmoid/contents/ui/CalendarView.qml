import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "calendar.js" as Cal

ColumnLayout {
    id: calRoot
    required property var app

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 10

    // Picking-for-form Banner
    Rectangle {
        visible: app.pickingDateForForm
        Layout.fillWidth: true
        implicitHeight: 36
        radius: 6
        color: Qt.rgba(0.23, 0.51, 0.96, 0.2)
        border.width: 1
        border.color: Qt.rgba(0.23, 0.51, 0.96, 0.45)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: "📅 Click any day to set deadline for your task"
                font.pixelSize: 12
                font.bold: true
                color: "#93c5fd"
            }

            Rectangle {
                implicitHeight: 24
                implicitWidth: 64
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.1)
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 11
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        app.pickingDateForForm = false;
                        app.currentView = "tasks";
                    }
                }
            }
        }
    }

    // Calendar Navigation Bar
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            implicitHeight: 30
            implicitWidth: modeText.implicitWidth + 18
            radius: 6
            color: Qt.rgba(0.23, 0.51, 0.96, 0.2)
            border.width: 1
            border.color: Qt.rgba(0.23, 0.51, 0.96, 0.35)

            PlasmaComponents.Label {
                id: modeText
                anchors.centerIn: parent
                text: app.calIsJalali ? "شمسی (Jalali)" : "Gregorian (میلادی)"
                font.pixelSize: 12
                font.bold: true
                color: "#60a5fa"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    app.calIsJalali = !app.calIsJalali;
                    app.initCalendarToToday();
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitHeight: 30
            implicitWidth: 32
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            PlasmaComponents.Label { anchors.centerIn: parent; text: "◀"; font.pixelSize: 12 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.calPrevMonth() }
        }

        PlasmaComponents.Label {
            text: app.calIsJalali
                ? (Cal.FA_MONTHS[app.calMonth] + " " + app.calYear)
                : (Cal.EN_MONTHS[app.calMonth] + " " + app.calYear)
            font.pixelSize: 15
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            implicitHeight: 30
            implicitWidth: 32
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            PlasmaComponents.Label { anchors.centerIn: parent; text: "▶"; font.pixelSize: 12 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.calNextMonth() }
        }

        Rectangle {
            implicitHeight: 30
            implicitWidth: 54
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            PlasmaComponents.Label { anchors.centerIn: parent; text: "Today"; font.pixelSize: 12; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.initCalendarToToday() }
        }
    }

    // Weekday Headers (7 columns)
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
            model: app.calIsJalali ? Cal.FA_WEEKDAYS : Cal.EN_WEEKDAYS
            delegate: Rectangle {
                Layout.fillWidth: true
                height: 24
                color: "transparent"

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 12
                    font.bold: true
                    opacity: 0.6
                }
            }
        }
    }

    // Month Days Grid (7 columns)
    // CRITICAL: Empty placeholder cells use opacity: 0 & enabled: false (NOT visible: false)
    // so Qt GridLayout preserves exact weekday column offsets!
    GridLayout {
        id: calGrid
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
            model: app.calGridCells
            delegate: Rectangle {
                Layout.fillWidth: true
                height: 46
                radius: 6
                opacity: modelData.dayNumber !== "" ? 1.0 : 0.0
                enabled: modelData.dayNumber !== ""
                color: {
                    if (modelData.isoDate === app.calSelectedIso && modelData.isoDate !== "") {
                        return Qt.rgba(0.23, 0.51, 0.96, 0.35);
                    }
                    if (modelData.isToday) return Qt.rgba(1, 1, 1, 0.12);
                    return cellHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04);
                }
                border.width: modelData.isToday || (modelData.isoDate === app.calSelectedIso && modelData.isoDate !== "") ? 1.5 : 1
                border.color: {
                    if (modelData.isoDate === app.calSelectedIso && modelData.isoDate !== "") return "#3b82f6";
                    if (modelData.isToday) return "#60a5fa";
                    return Qt.rgba(1, 1, 1, 0.08);
                }

                HoverHandler { id: cellHover }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    PlasmaComponents.Label {
                        text: modelData.dayNumber
                        font.pixelSize: 14
                        font.bold: modelData.isToday || modelData.isoDate === app.calSelectedIso
                        Layout.alignment: Qt.AlignHCenter
                        color: modelData.isToday ? "#60a5fa" : Kirigami.Theme.textColor
                    }

                    PlasmaComponents.Label {
                        text: modelData.subDayNumber
                        font.pixelSize: 10
                        opacity: 0.45
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Task Indicator Dot (colored by highest priority on that day)
                Rectangle {
                    visible: modelData.taskCount > 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 5
                    height: 5
                    radius: 3
                    color: app.getPriorityColor(modelData.topPriority)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!modelData.isoDate) return;
                        app.calSelectedDay = parseInt(modelData.dayNumber, 10);
                        app.calSelectedIso = modelData.isoDate;
                        if (app.pickingDateForForm) {
                            app.applyPickedDate(modelData.isoDate);
                        }
                    }
                }
            }
        }
    }

    // Selected Date Tasks Panel (fills remaining space cleanly)
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 130
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.035)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PlasmaComponents.Label {
                    text: {
                        if (!app.calSelectedIso) return "Select a date";
                        return app.calIsJalali
                            ? Cal.formatIsoToJalaliLabel(app.calSelectedIso)
                            : app.calSelectedIso;
                    }
                    font.pixelSize: 13
                    font.bold: true
                }

                PlasmaComponents.Label {
                    visible: app.calSelectedIso !== ""
                    text: app.calIsJalali ? app.calSelectedIso : Cal.formatIsoToJalaliLabel(app.calSelectedIso)
                    font.pixelSize: 11
                    opacity: 0.55
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: app.calSelectedIso !== ""
                    implicitHeight: 24
                    implicitWidth: addOnDateLbl.implicitWidth + 14
                    radius: 4
                    color: Qt.rgba(0.23, 0.51, 0.96, 0.2)
                    border.width: 1
                    border.color: Qt.rgba(0.23, 0.51, 0.96, 0.35)

                    PlasmaComponents.Label {
                        id: addOnDateLbl
                        anchors.centerIn: parent
                        text: "+ Add on date"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#60a5fa"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            app.openNewTaskForm();
                            app.formDueDate = app.calSelectedIso + " 18:00";
                            app.currentView = "tasks";
                        }
                    }
                }
            }

            ListView {
                id: dayTasksList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: {
                    if (!app.calSelectedIso) return [];
                    return app.calendarTasksList.filter(function(t) {
                        return t.due_iso_date === app.calSelectedIso;
                    });
                }

                delegate: Rectangle {
                    width: dayTasksList.width
                    implicitHeight: 32
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.04)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: modelData.completed ? "#10b981" : app.getPriorityColor(modelData.priority)

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: app.toggleTask(modelData.id)
                            }
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: modelData.title
                            font.pixelSize: 12
                            font.strikeout: modelData.completed
                            opacity: modelData.completed ? 0.5 : 0.95
                            elide: Text.ElideRight
                        }

                        PlasmaComponents.Label {
                            visible: (modelData.due_time || "") !== ""
                            text: modelData.due_time || ""
                            font.pixelSize: 11
                            font.family: "Monospace"
                            opacity: 0.7
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                visible: app.calSelectedIso !== "" && dayTasksList.count === 0
                text: "No tasks due on this day."
                font.pixelSize: 12
                opacity: 0.5
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
