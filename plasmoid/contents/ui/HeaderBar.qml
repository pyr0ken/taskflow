import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

RowLayout {
    id: headerRoot
    required property var app

    Layout.fillWidth: true
    spacing: 8

    // Live Indicator Dot
    Rectangle {
        width: 9
        height: 9
        radius: 5
        color: app.daemonOnline ? (app.overdueCount > 0 ? "#ef4444" : "#3b82f6") : "#64748b"
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: 5
            visible: app.daemonOnline
            color: app.overdueCount > 0 ? Qt.rgba(0.94, 0.27, 0.27, 0.25) : Qt.rgba(0.23, 0.51, 0.96, 0.25)
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: app.daemonOnline
                NumberAnimation { from: 1.0; to: 1.45; duration: 1200; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.45; to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
            }
        }
    }

    PlasmaComponents.Label {
        text: "TaskFlow"
        font.pixelSize: 17
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
    }

    // View Switcher Tabs
    RowLayout {
        spacing: 4
        Layout.leftMargin: 4

        Rectangle {
            implicitHeight: 28
            implicitWidth: tabTaskText.implicitWidth + 14
            radius: 6
            color: app.currentView === "tasks" ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            border.width: 1
            border.color: app.currentView === "tasks" ? Qt.rgba(1, 1, 1, 0.2) : "transparent"

            PlasmaComponents.Label {
                id: tabTaskText
                anchors.centerIn: parent
                text: "Tasks (" + app.pendingCount + ")"
                font.pixelSize: 12
                font.bold: app.currentView === "tasks"
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

        Rectangle {
            implicitHeight: 28
            implicitWidth: tabCalText.implicitWidth + 14
            radius: 6
            color: app.currentView === "calendar" ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            border.width: 1
            border.color: app.currentView === "calendar" ? Qt.rgba(1, 1, 1, 0.2) : "transparent"

            PlasmaComponents.Label {
                id: tabCalText
                anchors.centerIn: parent
                text: "Calendar"
                font.pixelSize: 12
                font.bold: app.currentView === "calendar"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    app.pickingDateForForm = false;
                    app.currentView = "calendar";
                    app.fetchCalendarTasks();
                }
            }
        }

        Rectangle {
            implicitHeight: 28
            implicitWidth: tabSetText.implicitWidth + 14
            radius: 6
            color: app.currentView === "settings" ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            border.width: 1
            border.color: app.currentView === "settings" ? Qt.rgba(1, 1, 1, 0.2) : "transparent"

            PlasmaComponents.Label {
                id: tabSetText
                anchors.centerIn: parent
                text: "Settings"
                font.pixelSize: 12
                font.bold: app.currentView === "settings"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    app.pickingDateForForm = false;
                    app.currentView = "settings";
                    app.fetchSettings();
                }
            }
        }
    }

    Item { Layout.fillWidth: true }

    // Offline warning chip
    Rectangle {
        visible: !app.daemonOnline
        implicitHeight: 24
        implicitWidth: offlineLbl.implicitWidth + 12
        radius: 5
        color: Qt.rgba(0.94, 0.27, 0.27, 0.2)
        border.width: 1
        border.color: Qt.rgba(0.94, 0.27, 0.27, 0.45)

        PlasmaComponents.Label {
            id: offlineLbl
            anchors.centerIn: parent
            text: "Offline"
            font.pixelSize: 11
            font.bold: true
            color: "#fca5a5"
        }
    }

    // "+ New Task" / "Cancel" Button
    Rectangle {
        visible: app.currentView === "tasks"
        implicitHeight: 28
        implicitWidth: newBtnText.implicitWidth + 16
        radius: 6
        color: newBtnHover.hovered
            ? (app.isFormOpen ? Qt.rgba(0.94, 0.27, 0.27, 0.22) : Qt.rgba(0.23, 0.51, 0.96, 0.28))
            : (app.isFormOpen ? Qt.rgba(0.94, 0.27, 0.27, 0.14) : Qt.rgba(0.23, 0.51, 0.96, 0.18))
        border.width: 1
        border.color: app.isFormOpen ? Qt.rgba(0.94, 0.27, 0.27, 0.4) : Qt.rgba(0.23, 0.51, 0.96, 0.4)

        HoverHandler { id: newBtnHover }

        PlasmaComponents.Label {
            id: newBtnText
            anchors.centerIn: parent
            text: app.isFormOpen ? "✕ Cancel" : "+ New Task"
            font.pixelSize: 12
            font.bold: true
            color: app.isFormOpen ? "#f87171" : "#60a5fa"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (app.isFormOpen) {
                    app.closeTaskForm();
                } else {
                    app.openNewTaskForm();
                }
            }
        }
    }
}
