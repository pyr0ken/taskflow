import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: settingsRoot
    required property var app

    property bool confirmClear: false

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 12

    // Card 1: Notifications
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: notifCol.implicitHeight + 24
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)

        ColumnLayout {
            id: notifCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            PlasmaComponents.Label {
                text: "Notifications & Alerts"
                font.pixelSize: 14
                font.bold: true
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.08 }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Enable Desktop Notifications"; font.pixelSize: 13; Layout.fillWidth: true }
                QQC2.Switch {
                    checked: app.notifEnabled
                    onToggled: {
                        app.notifEnabled = checked;
                        app.saveSettings("notifications_enabled", checked ? "true" : "false");
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Reminder 1 Hour Before"; font.pixelSize: 13; opacity: app.notifEnabled ? 1.0 : 0.4; Layout.fillWidth: true }
                QQC2.Switch {
                    enabled: app.notifEnabled
                    checked: app.notif60m
                    onToggled: {
                        app.notif60m = checked;
                        app.saveSettings("notify_60m", checked ? "true" : "false");
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Urgent Reminder 15m Before"; font.pixelSize: 13; opacity: app.notifEnabled ? 1.0 : 0.4; Layout.fillWidth: true }
                QQC2.Switch {
                    enabled: app.notifEnabled
                    checked: app.notif15m
                    onToggled: {
                        app.notif15m = checked;
                        app.saveSettings("notify_15m", checked ? "true" : "false");
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Alert When Task Reaches Deadline"; font.pixelSize: 13; opacity: app.notifEnabled ? 1.0 : 0.4; Layout.fillWidth: true }
                QQC2.Switch {
                    enabled: app.notifEnabled
                    checked: app.notifDue
                    onToggled: {
                        app.notifDue = checked;
                        app.saveSettings("notify_due", checked ? "true" : "false");
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Interactive Actions (Done / Snooze 15m)"; font.pixelSize: 13; opacity: app.notifEnabled ? 1.0 : 0.4; Layout.fillWidth: true }
                QQC2.Switch {
                    enabled: app.notifEnabled
                    checked: app.interactiveNotifs
                    onToggled: {
                        app.interactiveNotifs = checked;
                        app.saveSettings("interactive_notifications", checked ? "true" : "false");
                    }
                }
            }
        }
    }

    // Card 2: Preferences (Calendar + Default Priority)
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: prefCol.implicitHeight + 24
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)

        ColumnLayout {
            id: prefCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            PlasmaComponents.Label {
                text: "Calendar & Defaults"
                font.pixelSize: 14
                font.bold: true
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.08 }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Default Calendar"; font.pixelSize: 13; Layout.fillWidth: true }

                Rectangle {
                    implicitHeight: 28
                    implicitWidth: 88
                    radius: 5
                    color: app.calIsJalali ? "#2563eb" : Qt.rgba(1, 1, 1, 0.08)
                    PlasmaComponents.Label { anchors.centerIn: parent; text: "شمسی"; font.pixelSize: 12; font.bold: true; color: app.calIsJalali ? "#ffffff" : Kirigami.Theme.textColor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            app.calIsJalali = true;
                            app.preferredCalendar = "jalali";
                            app.saveSettings("calendar_mode", "jalali");
                            app.initCalendarToToday();
                        }
                    }
                }

                Rectangle {
                    implicitHeight: 28
                    implicitWidth: 88
                    radius: 5
                    color: !app.calIsJalali ? "#2563eb" : Qt.rgba(1, 1, 1, 0.08)
                    PlasmaComponents.Label { anchors.centerIn: parent; text: "Gregorian"; font.pixelSize: 12; font.bold: true; color: !app.calIsJalali ? "#ffffff" : Kirigami.Theme.textColor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            app.calIsJalali = false;
                            app.preferredCalendar = "gregorian";
                            app.saveSettings("calendar_mode", "gregorian");
                            app.initCalendarToToday();
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                PlasmaComponents.Label { text: "Default Task Priority"; font.pixelSize: 13; Layout.fillWidth: true }

                Repeater {
                    model: [
                        { p: 1, label: "P1" },
                        { p: 2, label: "P2" },
                        { p: 3, label: "P3" },
                        { p: 4, label: "P4" }
                    ]
                    delegate: Rectangle {
                        implicitHeight: 26
                        implicitWidth: 36
                        radius: 5
                        property bool isSel: parseInt(app.defaultPriority, 10) === modelData.p
                        color: isSel ? app.getPriorityColor(modelData.p) : Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1
                        border.color: isSel ? app.getPriorityColor(modelData.p) : Qt.rgba(1, 1, 1, 0.12)

                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 11
                            font.bold: true
                            color: isSel ? "#ffffff" : Kirigami.Theme.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                app.defaultPriority = "" + modelData.p;
                                app.saveSettings("default_priority", "" + modelData.p);
                            }
                        }
                    }
                }
            }
        }
    }

    // Card 3: Daemon Status & Storage
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: dataCol.implicitHeight + 24
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)

        ColumnLayout {
            id: dataCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            PlasmaComponents.Label {
                text: "Daemon & Storage"
                font.pixelSize: 14
                font.bold: true
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.08 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PlasmaComponents.Label { text: "Endpoint:"; font.pixelSize: 12; opacity: 0.7 }
                PlasmaComponents.Label { text: "http://127.0.0.1:28490"; font.pixelSize: 12; font.bold: true; font.family: "Monospace" }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: app.daemonOnline ? "#10b981" : "#ef4444"
                }
                PlasmaComponents.Label {
                    text: app.daemonOnline ? "Online" : "Offline"
                    font.pixelSize: 12
                    color: app.daemonOnline ? "#10b981" : "#ef4444"
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Database:"; font.pixelSize: 12; opacity: 0.7 }
                PlasmaComponents.Label { text: "~/.local/share/plasma-taskflow/tasks.db"; font.pixelSize: 11; font.family: "Monospace"; elide: Text.ElideMiddle; Layout.fillWidth: true }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 6
                color: settingsRoot.confirmClear
                    ? Qt.rgba(0.94, 0.27, 0.27, 0.35)
                    : (clearHover.hovered ? Qt.rgba(0.94, 0.27, 0.27, 0.25) : Qt.rgba(0.94, 0.27, 0.27, 0.14))
                border.width: 1
                border.color: Qt.rgba(0.94, 0.27, 0.27, 0.45)

                HoverHandler { id: clearHover }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: settingsRoot.confirmClear
                        ? ("Click again to permanently delete " + app.completedCount + " completed task(s)")
                        : ("Clear Completed Tasks (" + app.completedCount + ")")
                    font.pixelSize: 12
                    font.bold: true
                    color: "#f87171"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!settingsRoot.confirmClear) {
                            settingsRoot.confirmClear = true;
                        } else {
                            settingsRoot.confirmClear = false;
                            app.clearCompletedTasks();
                        }
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
