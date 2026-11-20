import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: taskCard
    property var app: null
    property var taskData: ({ completed: false, priority: 3, title: "", due_date: "", notes: "", tag: "", estimate: "", recurrence: "", subtasks_count: 0, subtasks_done: 0, subtasks: [], is_overdue: false, priority_name: "Normal", due_short: "", due_jalali_date: "", due_time: "", due_rel: "" })
    property int itemIndex: -1
    property var listViewRef: null

    readonly property bool isDragged: (app && app.dragSourceIndex === itemIndex && dragArea.drag.active)
    readonly property int shiftStep: (app ? app.dragCardHeight : 0) + (listViewRef ? listViewRef.spacing : 10)
    readonly property real targetShiftY: {
        if (!app || app.dragSourceIndex === -1 || itemIndex === app.dragSourceIndex || taskData.completed) return 0;
        if (app.dragSourceIndex < app.dragTargetIndex && itemIndex > app.dragSourceIndex && itemIndex <= app.dragTargetIndex) {
            return -shiftStep;
        }
        if (app.dragSourceIndex > app.dragTargetIndex && itemIndex >= app.dragTargetIndex && itemIndex < app.dragSourceIndex) {
            return shiftStep;
        }
        return 0;
    }

    implicitHeight: Math.max(cardMainRow.implicitHeight + 16, 68)
    radius: 8
    z: isDragged ? 100 : 1
    scale: isDragged ? 1.02 : 1.0
    color: isDragged
        ? Qt.rgba(0.14, 0.22, 0.36, 0.94)
        : (taskData.completed ? Qt.rgba(1, 1, 1, 0.025) : Qt.rgba(1, 1, 1, 0.05))
    border.width: isDragged ? 2 : 1
    border.color: isDragged
        ? "#60a5fa"
        : (taskData.is_overdue && !taskData.completed
            ? Qt.rgba(0.94, 0.27, 0.27, 0.35)
            : (cardHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)))

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    transform: Translate {
        y: taskCard.targetShiftY
        Behavior on y {
            enabled: app && app.dragSourceIndex !== -1
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    property bool subtasksExpanded: false
    HoverHandler { id: cardHover }

    // Background drag-to-reorder & double-click-to-edit MouseArea (sits behind buttons inside cardMainRow)
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: true
        preventStealing: !taskData.completed
        cursorShape: drag.active ? Qt.ClosedHandCursor : (gripHover.hovered && !taskData.completed ? Qt.OpenHandCursor : Qt.ArrowCursor)
        drag.target: taskData.completed ? null : taskCard
        drag.axis: Drag.YAxis
        drag.threshold: 6
        drag.minimumY: -Math.round(taskCard.height * 0.4)
        drag.maximumY: listViewRef ? Math.max(0, listViewRef.contentHeight - Math.round(taskCard.height * 0.6)) : 9999

        property real startY: 0
        onPressed: startY = taskCard.y
        onDoubleClicked: (mouse) => {
            if (app && taskData && taskData.id) {
                mouse.accepted = true;
                app.openEditTaskForm(taskData);
            }
        }

        function syncTargetFromPointer() {
            if (listViewRef && taskCard.itemIndex >= 0) {
                var pt = dragArea.mapToItem(listViewRef.contentItem, dragArea.mouseX, dragArea.mouseY);
                listViewRef.updateDragTarget(taskCard.itemIndex, pt.y, taskCard.y, taskCard.height);
            }
        }

        onPositionChanged: (mouse) => {
            if (drag.active && listViewRef && taskCard.itemIndex >= 0) {
                var pt = dragArea.mapToItem(listViewRef.contentItem, mouse.x, mouse.y);
                listViewRef.updateDragTarget(taskCard.itemIndex, pt.y, taskCard.y, taskCard.height);
            }
        }

        drag.onActiveChanged: {
            if (!app) return;
            if (drag.active) {
                app.dragSourceIndex = taskCard.itemIndex;
                app.dragTargetIndex = taskCard.itemIndex;
                app.dragCardHeight = taskCard.height;
                syncTargetFromPointer();
            } else {
                syncTargetFromPointer();
                var fromIdx = app.dragSourceIndex;
                var toIdx = app.dragTargetIndex;
                app.dragSourceIndex = -1;
                app.dragTargetIndex = -1;
                app.dragCardHeight = 0;
                taskCard.y = startY;
                if (fromIdx !== -1 && toIdx !== -1 && fromIdx !== toIdx && listViewRef) {
                    var lv = listViewRef;
                    app.reorderTasks(lv.model, fromIdx, toIdx);
                    Qt.callLater(function() {
                        if (lv) lv.forceLayout();
                    });
                }
            }
        }
    }

    RowLayout {
        id: cardMainRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 8

        // Subtle Drag Handle Grip (for active tasks)
        Item {
            visible: !taskData.completed
            Layout.preferredWidth: 14
            Layout.fillHeight: true
            Layout.minimumHeight: 46

            HoverHandler { id: gripHover }

            Column {
                anchors.centerIn: parent
                spacing: 3
                opacity: (gripHover.hovered || taskCard.isDragged) ? 0.85 : 0.28
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Repeater {
                    model: 3
                    delegate: Row {
                        spacing: 3
                        Rectangle { width: 3; height: 3; radius: 1.5; color: taskCard.isDragged ? "#60a5fa" : Kirigami.Theme.textColor }
                        Rectangle { width: 3; height: 3; radius: 1.5; color: taskCard.isDragged ? "#60a5fa" : Kirigami.Theme.textColor }
                    }
                }
            }
        }

        // Full-height ergonomic checkbox column
        Rectangle {
            id: checkTarget
            Layout.preferredWidth: 46
            Layout.fillHeight: true
            Layout.minimumHeight: 50
            radius: 6
            color: checkHover.hovered
                ? (taskData.completed ? Qt.rgba(0.06, 0.72, 0.51, 0.2) : Qt.rgba(1, 1, 1, 0.12))
                : (taskData.completed ? Qt.rgba(0.06, 0.72, 0.51, 0.08) : Qt.rgba(1, 1, 1, 0.03))
            border.width: 1
            border.color: checkHover.hovered
                ? (taskData.completed ? "#10b981" : Qt.rgba(1, 1, 1, 0.25))
                : (taskData.completed ? Qt.rgba(0.06, 0.72, 0.51, 0.25) : "transparent")

            HoverHandler { id: checkHover }

            Rectangle {
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 12
                color: taskData.completed ? "#10b981" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 2
                border.color: taskData.completed
                    ? "#10b981"
                    : (checkHover.hovered ? "#3b82f6" : app.getPriorityColor(taskData.priority))

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#ffffff"
                    visible: taskData.completed || checkHover.hovered
                    opacity: taskData.completed ? 1.0 : 0.35
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: app.toggleTask(taskData.id)
            }
        }

        // Main Task Content Column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 5

            // Row 1: Title, Priority, Snooze, Edit, Delete
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: taskData.title
                    font.pixelSize: 15
                    font.bold: !taskData.completed
                    font.strikeout: taskData.completed
                    opacity: taskData.completed ? 0.45 : 0.95
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }

                // Quick Snooze +1h (for active tasks with due date)
                Rectangle {
                    visible: !taskData.completed && taskData.due_date !== ""
                    implicitHeight: 24
                    implicitWidth: snzTxt.implicitWidth + 12
                    radius: 6
                    color: snzHover.hovered ? Qt.rgba(0.98, 0.45, 0.09, 0.2) : Qt.rgba(1, 1, 1, 0.045)
                    border.width: 1
                    border.color: snzHover.hovered ? Qt.rgba(0.98, 0.45, 0.09, 0.5) : Qt.rgba(1, 1, 1, 0.09)
                    Layout.alignment: Qt.AlignVCenter

                    HoverHandler { id: snzHover }

                    PlasmaComponents.Label {
                        id: snzTxt
                        anchors.centerIn: parent
                        text: "+1h"
                        font.pixelSize: 11
                        font.bold: true
                        color: snzHover.hovered ? "#fb923c" : Kirigami.Theme.textColor
                        opacity: snzHover.hovered ? 1.0 : 0.7
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: app.snoozeTask(taskData.id, "1h")
                    }
                }

                // Interactive Priority Chip (click to pick, right-click to cycle)
                Rectangle {
                    id: prioChip
                    implicitHeight: 24
                    implicitWidth: prioRow.implicitWidth + 14
                    radius: 6
                    color: prioHover.hovered
                        ? Qt.lighter(app.getPriorityBg(taskData.priority), 1.25)
                        : app.getPriorityBg(taskData.priority)
                    border.width: 1
                    border.color: prioHover.hovered
                        ? app.getPriorityColor(taskData.priority)
                        : app.getPriorityBorder(taskData.priority)
                    Layout.alignment: Qt.AlignVCenter

                    HoverHandler { id: prioHover }

                    RowLayout {
                        id: prioRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: app.getPriorityColor(taskData.priority)
                        }

                        PlasmaComponents.Label {
                            text: taskData.priority_name
                            font.pixelSize: 11
                            font.bold: true
                            color: app.getPriorityColor(taskData.priority)
                        }

                        PlasmaComponents.Label {
                            text: "▾"
                            font.pixelSize: 9
                            color: app.getPriorityColor(taskData.priority)
                            opacity: prioHover.hovered ? 0.95 : 0.55
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                if (app.cycleTaskPriority) {
                                    app.cycleTaskPriority(taskData.id, taskData.priority);
                                }
                            } else {
                                if (app.openPriorityMenu) {
                                    app.openPriorityMenu(taskData, prioChip);
                                } else if (app.cycleTaskPriority) {
                                    app.cycleTaskPriority(taskData.id, taskData.priority);
                                }
                            }
                        }
                    }
                }

                // Grouped Action Pill (Edit + Delete with crisp SVG icons)
                Rectangle {
                    implicitHeight: 24
                    implicitWidth: actionGroupRow.implicitWidth + 4
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.035)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: actionGroupRow
                        anchors.centerIn: parent
                        spacing: 2

                        // Edit Button
                        Rectangle {
                            implicitHeight: 20
                            implicitWidth: 22
                            radius: 4
                            color: editHover.hovered ? Qt.rgba(0.23, 0.51, 0.96, 0.22) : "transparent"

                            HoverHandler { id: editHover }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                source: "document-edit-symbolic"
                                isMask: true
                                color: editHover.hovered ? "#60a5fa" : Kirigami.Theme.textColor
                                opacity: editHover.hovered ? 1.0 : 0.55
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: app.openEditTaskForm(taskData)
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 12
                            color: Kirigami.Theme.textColor
                            opacity: 0.12
                        }

                        // Delete Button
                        Rectangle {
                            implicitHeight: 20
                            implicitWidth: 22
                            radius: 4
                            color: delHover.hovered ? Qt.rgba(0.94, 0.27, 0.27, 0.22) : "transparent"

                            HoverHandler { id: delHover }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                source: "edit-delete-symbolic"
                                isMask: true
                                color: delHover.hovered ? "#ef4444" : Kirigami.Theme.textColor
                                opacity: delHover.hovered ? 1.0 : 0.5
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: app.deleteTask(taskData.id)
                            }
                        }
                    }
                }
            }

            // Optional Notes line
            PlasmaComponents.Label {
                visible: (taskData.notes || "") !== ""
                Layout.fillWidth: true
                text: taskData.notes || ""
                font.pixelSize: 11
                opacity: 0.58
                elide: Text.ElideRight
            }

            // Row 2: BiDi-safe Metadata Badges (Flow so badges never clip)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Due Date Badge (separated into pure RTL/LTR labels to avoid BiDi reversal)
                Rectangle {
                    visible: taskData.due_date !== ""
                    implicitHeight: 22
                    implicitWidth: dueBadgeRow.implicitWidth + 12
                    radius: 4
                    color: taskData.completed
                        ? Qt.rgba(1, 1, 1, 0.05)
                        : (taskData.is_overdue ? Qt.rgba(0.94, 0.27, 0.27, 0.16) : Qt.rgba(0.23, 0.51, 0.96, 0.14))
                    border.width: 1
                    border.color: taskData.is_overdue && !taskData.completed
                        ? Qt.rgba(0.94, 0.27, 0.27, 0.35)
                        : Qt.rgba(1, 1, 1, 0.1)

                    RowLayout {
                        id: dueBadgeRow
                        anchors.centerIn: parent
                        spacing: 5

                        PlasmaComponents.Label {
                            text: taskData.is_overdue && !taskData.completed ? "🚨" : "⏰"
                            font.pixelSize: 11
                        }

                        PlasmaComponents.Label {
                            text: app.calIsJalali && taskData.due_jalali_date
                                ? taskData.due_jalali_date
                                : taskData.due_short
                            font.pixelSize: 11
                            font.bold: taskData.is_overdue
                            color: taskData.is_overdue && !taskData.completed ? "#ef4444" : Kirigami.Theme.textColor
                            opacity: taskData.completed ? 0.45 : 0.95
                        }

                        PlasmaComponents.Label {
                            visible: (taskData.due_time || "") !== "" && app.calIsJalali
                            text: taskData.due_time || ""
                            font.pixelSize: 11
                            font.family: "Monospace"
                            font.bold: taskData.is_overdue
                            color: taskData.is_overdue && !taskData.completed ? "#fca5a5" : "#93c5fd"
                        }

                        PlasmaComponents.Label {
                            visible: (taskData.due_rel || "") !== "" && !taskData.completed
                            text: "• " + (taskData.due_rel || "")
                            font.pixelSize: 10
                            color: taskData.is_overdue ? "#fca5a5" : Kirigami.Theme.textColor
                            opacity: taskData.is_overdue ? 0.95 : 0.65
                        }
                    }
                }

                // Tag Chip (click to toggle tag filter)
                Rectangle {
                    visible: taskData.tag !== ""
                    implicitHeight: 22
                    implicitWidth: tagTxt.implicitWidth + 10
                    radius: 4
                    color: app.activeTag === taskData.tag ? Qt.rgba(0.23, 0.51, 0.96, 0.24) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: app.activeTag === taskData.tag ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.12)

                    PlasmaComponents.Label {
                        id: tagTxt
                        anchors.centerIn: parent
                        text: "#" + taskData.tag
                        font.pixelSize: 11
                        font.bold: true
                        opacity: 0.85
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            app.activeTag = (app.activeTag === taskData.tag) ? "" : taskData.tag;
                            app.fetchTasks();
                        }
                    }
                }

                // Estimate Chip
                Rectangle {
                    visible: taskData.estimate !== ""
                    implicitHeight: 22
                    implicitWidth: estTxt.implicitWidth + 10
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    PlasmaComponents.Label {
                        id: estTxt
                        anchors.centerIn: parent
                        text: "⏳ " + taskData.estimate
                        font.pixelSize: 11
                        opacity: 0.8
                    }
                }

                // Recurrence Chip
                Rectangle {
                    visible: (taskData.recurrence || "") !== ""
                    implicitHeight: 22
                    implicitWidth: recTxt.implicitWidth + 10
                    radius: 4
                    color: Qt.rgba(0.06, 0.72, 0.51, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(0.06, 0.72, 0.51, 0.28)

                    PlasmaComponents.Label {
                        id: recTxt
                        anchors.centerIn: parent
                        text: "↻ " + (taskData.recurrence || "")
                        font.pixelSize: 11
                        color: "#34d399"
                    }
                }

                Item { Layout.fillWidth: true }

                // Subtasks Toggle
                Rectangle {
                    visible: taskData.subtasks_count > 0 || taskCard.subtasksExpanded
                    implicitHeight: 22
                    implicitWidth: subSumTxt.implicitWidth + 12
                    radius: 5
                    color: subTogHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    HoverHandler { id: subTogHover }

                    PlasmaComponents.Label {
                        id: subSumTxt
                        anchors.centerIn: parent
                        text: (taskCard.subtasksExpanded ? "▴ " : "▾ ") + taskData.subtasks_done + "/" + taskData.subtasks_count
                        font.pixelSize: 11
                        font.bold: true
                        opacity: 0.85
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: taskCard.subtasksExpanded = !taskCard.subtasksExpanded
                    }
                }

                // Subtle "+ Sub" pill when empty
                Rectangle {
                    visible: taskData.subtasks_count === 0 && !taskCard.subtasksExpanded && !taskCard.taskData.completed
                    implicitHeight: 22
                    implicitWidth: subAddTxt.implicitWidth + 12
                    radius: 5
                    color: subAddHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.025)
                    border.width: 1
                    border.color: subAddHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.07)
                    opacity: (subAddHover.hovered || cardHover.hovered) ? 1.0 : 0.55

                    HoverHandler { id: subAddHover }

                    PlasmaComponents.Label {
                        id: subAddTxt
                        anchors.centerIn: parent
                        text: "+ Sub"
                        font.pixelSize: 11
                        opacity: subAddHover.hovered ? 0.95 : 0.7
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: taskCard.subtasksExpanded = true
                    }
                }
            }

            // Expanded Subtasks Section
            ColumnLayout {
                visible: taskCard.subtasksExpanded
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Kirigami.Theme.textColor
                    opacity: 0.1
                }

                Repeater {
                    model: taskData.subtasks
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 4
                            color: modelData.completed ? "#10b981" : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            border.color: modelData.completed ? "#10b981" : Qt.rgba(1, 1, 1, 0.25)

                            PlasmaComponents.Label {
                                anchors.centerIn: parent
                                text: "✓"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#ffffff"
                                visible: modelData.completed
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: app.toggleSubtask(modelData.id)
                            }
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: modelData.title
                            font.pixelSize: 12
                            font.strikeout: modelData.completed
                            opacity: modelData.completed ? 0.45 : 0.9
                        }

                        PlasmaComponents.Label {
                            text: "✕"
                            font.pixelSize: 11
                            opacity: 0.4
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: app.deleteSubtask(modelData.id)
                            }
                        }
                    }
                }

                // Inline Add Subtask
                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 4
                    color: Qt.rgba(0, 0, 0, 0.24)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    TextInput {
                        id: inlineSubInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 12
                        color: Kirigami.Theme.textColor
                        clip: true
                        onAccepted: {
                            if (text.trim()) {
                                app.addSubtaskToTask(taskData.id, text.trim());
                                text = "";
                            }
                        }

                        Text {
                            text: "+ Add subtask item (Enter)..."
                            font.pixelSize: 11
                            color: Kirigami.Theme.textColor
                            opacity: 0.4
                            visible: !inlineSubInput.text && !inlineSubInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
