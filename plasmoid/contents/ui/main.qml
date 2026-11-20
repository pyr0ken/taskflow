import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "calendar.js" as Cal

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    // Global daemon & summary state
    property bool daemonOnline: true
    property int pendingCount: 0
    property int completedCount: 0
    property int overdueCount: 0
    property int todayCount: 0
    property int urgentCount: 0
    property var nextTask: null
    property var focusTask: null
    property var activePillTasks: []
    property int pillTaskIndex: 0
    property var topUpcoming: []
    property var tasksList: []
    property var calendarTasksList: []
    property var tagsList: []
    property var allTagsList: []
    property int formFocusToken: 0

    // View & filter state
    property string activeFilter: "active" // active, today, completed, all
    property string activeTag: ""
    property string sortMode: "priority" // priority, due, created
    property string searchQuery: ""
    property string currentView: "tasks" // tasks, calendar, settings
    property bool isFormOpen: false
    property int editingTaskId: -1
    property bool pickingDateForForm: false

    // Drag-and-drop reorder state
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property real dragCardHeight: 0
    property Item draggedCardItem: null

    // Inline Priority Picker Menu state
    property Item fullRootItem: null
    property bool prioMenuVisible: false
    property int prioMenuTaskId: -1
    property int prioMenuCurrent: 3
    property real prioMenuX: 0
    property real prioMenuY: 0

    // Settings state
    property bool notifEnabled: true
    property bool notif60m: true
    property bool notif15m: true
    property bool notifDue: true
    property bool interactiveNotifs: true
    property string defaultPriority: "3"
    property string preferredCalendar: "jalali"

    // Calendar state
    property bool calIsJalali: true
    property int calYear: 1405
    property int calMonth: 8
    property int calSelectedDay: 1
    property string calSelectedIso: ""
    property var calGridCells: []

    // Create / Edit Task Form state
    property string formTitle: ""
    property string formDueDate: ""
    property int formPriority: 3
    property string formTag: ""
    property string formEstimate: ""
    property string formNotes: ""
    property string formRecurrence: ""
    property var formSubtasks: []
    property string formSubtaskInput: ""
    property string formError: ""

    function getPriorityColor(p) {
        if (p === 1) return "#ef4444";
        if (p === 2) return "#f97316";
        if (p === 3) return "#3b82f6";
        return "#64748b";
    }

    function getPriorityBg(p) {
        if (p === 1) return Qt.rgba(0.94, 0.27, 0.27, 0.15);
        if (p === 2) return Qt.rgba(0.98, 0.45, 0.09, 0.15);
        if (p === 3) return Qt.rgba(0.23, 0.51, 0.96, 0.15);
        return Qt.rgba(0.39, 0.45, 0.55, 0.15);
    }

    function getPriorityBorder(p) {
        if (p === 1) return Qt.rgba(0.94, 0.27, 0.27, 0.35);
        if (p === 2) return Qt.rgba(0.98, 0.45, 0.09, 0.35);
        if (p === 3) return Qt.rgba(0.23, 0.51, 0.96, 0.35);
        return Qt.rgba(0.39, 0.45, 0.55, 0.35);
    }

    function getPriorityName(p) {
        if (p === 1) return "Urgent";
        if (p === 2) return "High";
        if (p === 3) return "Medium";
        return "Low";
    }

    // HTTP Helpers
    function fetchStats() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:28490/stats");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        root.daemonOnline = true;
                        root.pendingCount = data.pending_count || 0;
                        root.completedCount = data.completed_count || 0;
                        root.overdueCount = data.overdue_count || 0;
                        root.todayCount = data.today_count || 0;
                        root.urgentCount = data.urgent_count || 0;
                        root.nextTask = data.next_task || null;
                        root.focusTask = data.focus_task || null;
                        root.activePillTasks = data.active_pill_tasks || [];
                        if (root.pillTaskIndex >= root.activePillTasks.length) {
                            root.pillTaskIndex = 0;
                        }
                        root.topUpcoming = data.top_upcoming || [];
                        root.tagsList = data.tags || [];
                        root.allTagsList = data.all_tags || [];
                    } catch (e) {
                        root.daemonOnline = false;
                    }
                } else {
                    root.daemonOnline = false;
                }
            }
        };
        xhr.send();
    }

    function fetchTasks() {
        var xhr = new XMLHttpRequest();
        var url = "http://127.0.0.1:28490/tasks?filter=" + encodeURIComponent(root.activeFilter)
            + "&sort=" + encodeURIComponent(root.sortMode);
        if (root.activeTag) {
            url += "&tag=" + encodeURIComponent(root.activeTag);
        }
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    root.tasksList = JSON.parse(xhr.responseText);
                    root.daemonOnline = true;
                } catch (e) {}
            }
        };
        xhr.send();
    }

    function fetchCalendarTasks() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:28490/calendar/month");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    root.calendarTasksList = data.tasks || [];
                    updateCalendarGrid();
                } catch (e) {}
            }
        };
        xhr.send();
    }

    function fetchSettings() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:28490/settings");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var s = JSON.parse(xhr.responseText);
                    root.notifEnabled = (s.notifications_enabled !== "false");
                    root.notif60m = (s.notify_60m !== "false");
                    root.notif15m = (s.notify_15m !== "false");
                    root.notifDue = (s.notify_due !== "false");
                    root.interactiveNotifs = (s.interactive_notifications !== "false");
                    root.defaultPriority = s.default_priority || "3";
                    root.preferredCalendar = s.calendar_mode || "jalali";
                    root.calIsJalali = (root.preferredCalendar === "jalali");
                    if (!root.isFormOpen && root.editingTaskId < 0) {
                        root.formPriority = parseInt(root.defaultPriority, 10) || 3;
                    }
                    initCalendarToToday();
                } catch (e) {}
            }
        };
        xhr.send();
    }

    function saveSettings(key, val) {
        var payload = {};
        payload[key] = val;
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:28490/settings");
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(payload));
    }

    function clearCompletedTasks() {
        postAction("/tasks/clear-completed", {});
    }

    function postAction(endpoint, payload, onSuccess, onError) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:28490" + endpoint);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    fetchStats();
                    fetchTasks();
                    fetchCalendarTasks();
                    if (onSuccess) onSuccess();
                } else {
                    var msg = "Request failed (" + xhr.status + ")";
                    try {
                        var errObj = JSON.parse(xhr.responseText);
                        if (errObj.error) msg = errObj.error;
                    } catch (e) {}
                    if (onError) onError(msg);
                }
            }
        };
        xhr.send(JSON.stringify(payload));
    }

    function toggleTask(taskId) {
        postAction("/tasks/toggle", { id: taskId });
    }

    function deleteTask(taskId) {
        if (root.editingTaskId === taskId) {
            closeTaskForm();
        }
        postAction("/tasks/delete", { id: taskId });
    }

    function snoozeTask(taskId, preset) {
        postAction("/tasks/snooze", { id: taskId, preset: preset || "1h" });
    }

    function setTaskPriority(taskId, newPriority) {
        var p = Math.max(1, Math.min(4, parseInt(newPriority, 10) || 3));
        root.prioMenuVisible = false;
        var updated = JSON.parse(JSON.stringify(root.tasksList || []));
        for (var i = 0; i < updated.length; ++i) {
            if (updated[i].id === taskId) {
                updated[i].priority = p;
                updated[i].priority_name = getPriorityName(p);
                break;
            }
        }
        root.tasksList = updated;
        postAction("/tasks/update", { id: taskId, priority: p });
    }

    function cycleTaskPriority(taskId, currentPriority) {
        var nextP = (parseInt(currentPriority, 10) || 3) % 4 + 1;
        setTaskPriority(taskId, nextP);
    }

    function openPriorityMenu(taskObj, anchorItem) {
        if (!taskObj || !anchorItem) return;
        if (root.prioMenuVisible && root.prioMenuTaskId === taskObj.id) {
            root.prioMenuVisible = false;
            return;
        }
        var targetRoot = root.fullRootItem;
        if (!targetRoot) {
            cycleTaskPriority(taskObj.id, taskObj.priority);
            return;
        }
        var pt = anchorItem.mapToItem(targetRoot, 0, anchorItem.height + 5);
        var menuW = 132;
        var menuH = 126;
        var maxW = targetRoot.width > 0 ? targetRoot.width : 560;
        var maxH = targetRoot.height > 0 ? targetRoot.height : 720;
        var x = Math.max(10, Math.min(pt.x + anchorItem.width - menuW, maxW - menuW - 10));
        var y = pt.y;
        if (y + menuH > maxH - 10) {
            y = Math.max(10, pt.y - anchorItem.height - menuH - 10);
        }
        root.prioMenuTaskId = taskObj.id;
        root.prioMenuCurrent = taskObj.priority || 3;
        root.prioMenuX = x;
        root.prioMenuY = y;
        root.prioMenuVisible = true;
    }

    function toggleSubtask(subtaskId) {
        postAction("/subtasks/toggle", { id: subtaskId });
    }

    function addSubtaskToTask(taskId, title) {
        if (!title || !title.trim()) return;
        postAction("/subtasks/add", { task_id: taskId, title: title.trim() });
    }

    function deleteSubtask(subtaskId) {
        postAction("/subtasks/delete", { id: subtaskId });
    }

    function reorderTasks(visibleList, fromIndex, toIndex) {
        if (!visibleList || fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return;
        if (fromIndex >= visibleList.length || toIndex >= visibleList.length) return;
        var copy = JSON.parse(JSON.stringify(visibleList));
        var movedTask = copy[fromIndex];
        var targetTask = copy[toIndex];
        if (!movedTask || !targetTask || movedTask.completed || targetTask.completed) return;

        copy.splice(fromIndex, 1);
        copy.splice(toIndex, 0, movedTask);

        var orderedIds = [];
        for (var i = 0; i < copy.length; ++i) {
            if (copy[i].completed === 0) {
                orderedIds.push(copy[i].id);
            }
        }
        if (orderedIds.length === 0) return;

        if (root.sortMode === "due") {
            root.sortMode = "priority";
        }

        if (!root.searchQuery) {
            root.tasksList = copy;
        }

        postAction("/tasks/reorder", {
            ordered_ids: orderedIds
        });
    }

    function openNewTaskForm() {
        root.editingTaskId = -1;
        root.formTitle = "";
        root.formDueDate = "";
        root.formPriority = parseInt(root.defaultPriority, 10) || 3;
        root.formTag = root.activeTag || "";
        root.formEstimate = "";
        root.formNotes = "";
        root.formRecurrence = "";
        root.formSubtasks = [];
        root.formSubtaskInput = "";
        root.formError = "";
        root.isFormOpen = true;
        root.formFocusToken += 1;
    }

    function openEditTaskForm(taskObj) {
        root.editingTaskId = taskObj.id;
        root.formTitle = taskObj.title || "";
        root.formDueDate = taskObj.due_date || "";
        root.formPriority = taskObj.priority || 3;
        root.formTag = taskObj.tag || "";
        root.formEstimate = taskObj.estimate || "";
        root.formNotes = taskObj.notes || "";
        root.formRecurrence = taskObj.recurrence || "";
        root.formSubtasks = [];
        root.formSubtaskInput = "";
        root.formError = "";
        root.isFormOpen = true;
        root.formFocusToken += 1;
    }

    function closeTaskForm() {
        root.isFormOpen = false;
        root.editingTaskId = -1;
        root.pickingDateForForm = false;
        root.formError = "";
    }

    function submitTaskForm() {
        if (!root.formTitle.trim()) {
            root.formError = "Task title is required.";
            return;
        }
        root.formError = "";
        if (root.editingTaskId > 0) {
            var editPayload = {
                id: root.editingTaskId,
                title: root.formTitle.trim(),
                due_date: root.formDueDate.trim(),
                priority: root.formPriority,
                tag: root.formTag.trim(),
                estimate: root.formEstimate.trim(),
                notes: root.formNotes.trim(),
                recurrence: root.formRecurrence
            };
            postAction("/tasks/update", editPayload, function() {
                closeTaskForm();
            }, function(errMsg) {
                root.formError = errMsg;
            });
        } else {
            var addPayload = {
                title: root.formTitle.trim(),
                due_date: root.formDueDate.trim(),
                priority: root.formPriority,
                tag: root.formTag.trim(),
                estimate: root.formEstimate.trim(),
                notes: root.formNotes.trim(),
                recurrence: root.formRecurrence,
                subtasks: root.formSubtasks
            };
            postAction("/tasks", addPayload, function() {
                closeTaskForm();
            }, function(errMsg) {
                root.formError = errMsg;
            });
        }
    }

    function setQuickDue(hoursOffset) {
        var d = new Date();
        d.setHours(d.getHours() + hoursOffset);
        var yyyy = d.getFullYear();
        var mm = Cal.padZero(d.getMonth() + 1);
        var dd = Cal.padZero(d.getDate());
        var hh = Cal.padZero(d.getHours());
        var min = Cal.padZero(d.getMinutes());
        root.formDueDate = yyyy + "-" + mm + "-" + dd + " " + hh + ":" + min;
    }

    function setQuickTime(hhmm) {
        var cur = root.formDueDate.trim();
        var datePart = "";
        if (cur && /^\d{4}[-/]\d{1,2}[-/]\d{1,2}/.test(cur)) {
            datePart = cur.split(/[T\s]/)[0];
        } else {
            var now = new Date();
            datePart = now.getFullYear() + "-" + Cal.padZero(now.getMonth() + 1) + "-" + Cal.padZero(now.getDate());
        }
        root.formDueDate = datePart + " " + hhmm;
    }

    function applyPickedDate(isoDate) {
        var cur = root.formDueDate.trim();
        var timePart = "18:00";
        var parts = cur.split(/[T\s]/);
        if (parts.length > 1 && /^\d{1,2}:\d{2}/.test(parts[1])) {
            timePart = parts[1].slice(0, 5);
        }
        root.formDueDate = isoDate + " " + timePart;
        root.pickingDateForForm = false;
        root.isFormOpen = true;
        root.currentView = "tasks";
    }

    // Calendar logic
    function updateCalendarGrid() {
        var dateMeta = {};
        var src = root.calendarTasksList.length > 0 ? root.calendarTasksList : root.tasksList;
        for (var i = 0; i < src.length; ++i) {
            var t = src[i];
            if (t.completed === 0 && t.due_iso_date) {
                var iso = t.due_iso_date;
                if (!dateMeta[iso]) {
                    dateMeta[iso] = { count: 1, topPriority: t.priority };
                } else {
                    dateMeta[iso].count += 1;
                    if (t.priority < dateMeta[iso].topPriority) {
                        dateMeta[iso].topPriority = t.priority;
                    }
                }
            }
        }
        root.calGridCells = Cal.generateMonthGrid(root.calYear, root.calMonth, root.calIsJalali, dateMeta);
    }

    function initCalendarToToday() {
        var now = new Date();
        var todayIso = now.getFullYear() + "-" + Cal.padZero(now.getMonth() + 1) + "-" + Cal.padZero(now.getDate());
        root.calSelectedIso = todayIso;
        if (root.calIsJalali) {
            var j = Cal.gregorianToJalali(now.getFullYear(), now.getMonth() + 1, now.getDate());
            root.calYear = j.jy;
            root.calMonth = j.jm;
            root.calSelectedDay = j.jd;
        } else {
            root.calYear = now.getFullYear();
            root.calMonth = now.getMonth() + 1;
            root.calSelectedDay = now.getDate();
        }
        updateCalendarGrid();
    }

    function calPrevMonth() {
        if (root.calMonth > 1) {
            root.calMonth -= 1;
        } else {
            root.calMonth = 12;
            root.calYear -= 1;
        }
        updateCalendarGrid();
    }

    function calNextMonth() {
        if (root.calMonth < 12) {
            root.calMonth += 1;
        } else {
            root.calMonth = 1;
            root.calYear += 1;
        }
        updateCalendarGrid();
    }

    Timer {
        id: refreshTimer
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.dragSourceIndex !== -1) return;
            fetchStats();
            if (root.expanded) {
                fetchTasks();
                if (root.currentView === "calendar") {
                    fetchCalendarTasks();
                }
            }
        }
    }

    Component.onCompleted: {
        initCalendarToToday();
        fetchSettings();
    }

    onExpandedChanged: {
        if (root.expanded) {
            fetchStats();
            fetchTasks();
            fetchCalendarTasks();
            fetchSettings();
        }
    }

    // ==========================================
    // HOVER TOOLTIP CARD
    // ==========================================
    toolTipMainText: "TaskFlow"
    toolTipItem: Item {
        id: tooltipRoot
        implicitWidth: 360
        implicitHeight: tooltipCol.implicitHeight + 24

        ColumnLayout {
            id: tooltipCol
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: !root.daemonOnline ? "#64748b" : (root.overdueCount > 0 ? "#ef4444" : (root.pendingCount > 0 ? "#3b82f6" : "#10b981"))
                }

                PlasmaComponents.Label {
                    text: "TASKFLOW OVERVIEW"
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.6
                    opacity: 0.95
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents.Label {
                    text: root.daemonOnline ? (root.pendingCount + " pending") : "Offline"
                    font.pixelSize: 12
                    font.bold: true
                    opacity: 0.7
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.textColor
                opacity: 0.12
            }

            Repeater {
                model: root.topUpcoming
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 4
                        height: 28
                        radius: 2
                        color: root.getPriorityColor(modelData.priority)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        PlasmaComponents.Label {
                            text: modelData.title
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // BiDi-safe split labels (no RTL+LTR parentheses mixing)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            PlasmaComponents.Label {
                                text: root.calIsJalali && modelData.due_jalali_date
                                    ? modelData.due_jalali_date
                                    : modelData.due_short
                                font.pixelSize: 11
                                color: modelData.is_overdue ? "#ef4444" : Kirigami.Theme.textColor
                                opacity: modelData.is_overdue ? 1.0 : 0.7
                            }

                            PlasmaComponents.Label {
                                visible: (modelData.due_time || "") !== "" && root.calIsJalali
                                text: modelData.due_time || ""
                                font.pixelSize: 11
                                font.family: "Monospace"
                                color: modelData.is_overdue ? "#fca5a5" : "#93c5fd"
                            }

                            PlasmaComponents.Label {
                                visible: (modelData.due_rel || "") !== ""
                                text: "• " + (modelData.due_rel || "")
                                font.pixelSize: 11
                                color: modelData.is_overdue ? "#ef4444" : Kirigami.Theme.textColor
                                opacity: modelData.is_overdue ? 0.95 : 0.6
                            }
                        }
                    }
                }
            }

            Item {
                visible: root.topUpcoming.length === 0
                Layout.fillWidth: true
                implicitHeight: 28
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: "No upcoming tasks"
                    font.pixelSize: 12
                    opacity: 0.5
                }
            }
        }
    }

    // ==========================================
    // COMPACT REPRESENTATION (Smart 3-Part Panel Pill)
    // ==========================================
    compactRepresentation: Item {
        id: compactRoot

        readonly property var currentPillTask: {
            if (root.activePillTasks && root.activePillTasks.length > 0) {
                var idx = Math.max(0, Math.min(root.pillTaskIndex, root.activePillTasks.length - 1));
                if (idx === 0 && root.focusTask) return root.focusTask;
                return root.activePillTasks[idx];
            }
            return root.focusTask || root.nextTask;
        }

        readonly property string contextBadgeText: {
            if (!root.daemonOnline) return "";
            var t = currentPillTask;
            if (root.overdueCount > 0) {
                return root.overdueCount + " late";
            }
            if (t && t.due_rel) {
                return t.due_rel.replace(/^in\s+/, "");
            }
            if (t && t.estimate) {
                return t.estimate;
            }
            if (t && t.tag) {
                return "#" + t.tag;
            }
            if (root.urgentCount > 0) {
                return root.urgentCount + " P1";
            }
            return "";
        }

        readonly property string contextBadgeKind: {
            if (root.overdueCount > 0) return "overdue";
            var t = currentPillTask;
            if (t && t.due_rel) return (t.diff_mins <= 180 ? "soon" : "due");
            if (root.urgentCount > 0 && !(t && (t.estimate || t.tag))) return "urgent";
            return "meta";
        }

        Layout.minimumWidth: pillBox.implicitWidth + 6
        Layout.preferredWidth: pillBox.implicitWidth + 6
        Layout.maximumWidth: 400
        Layout.minimumHeight: 36
        Layout.preferredHeight: compactRoot.parent ? compactRoot.parent.height : 38

        HoverHandler { id: pillHover }

        WheelHandler {
            enabled: root.activePillTasks && root.activePillTasks.length > 1
            onWheel: (event) => {
                var n = root.activePillTasks.length;
                if (n <= 1) return;
                if (event.angleDelta.y < 0) {
                    root.pillTaskIndex = (root.pillTaskIndex + 1) % n;
                } else if (event.angleDelta.y > 0) {
                    root.pillTaskIndex = (root.pillTaskIndex - 1 + n) % n;
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        Rectangle {
            id: pillBox
            anchors.centerIn: parent
            implicitHeight: 38
            height: compactRoot.height > 4 ? Math.max(34, compactRoot.height - 2) : implicitHeight
            implicitWidth: Math.min(392, pillRow.implicitWidth + 24)
            radius: 10
            color: pillHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: root.overdueCount > 0
                ? Qt.rgba(0.94, 0.27, 0.27, 0.48)
                : (pillHover.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1))

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: pillRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, pillBox.width - 24)
                spacing: 9

                // Part 1: Priority Dot + Important Task Title
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: !root.daemonOnline
                        ? "#64748b"
                        : (compactRoot.currentPillTask
                            ? root.getPriorityColor(compactRoot.currentPillTask.priority)
                            : "#10b981")
                    Layout.alignment: Qt.AlignVCenter
                }

                PlasmaComponents.Label {
                    text: {
                        if (!root.daemonOnline) return "Offline";
                        if (compactRoot.currentPillTask && compactRoot.currentPillTask.title) {
                            return compactRoot.currentPillTask.title;
                        }
                        return "All clear";
                    }
                    font.pixelSize: 13
                    font.bold: true
                    color: !root.daemonOnline
                        ? "#94a3b8"
                        : (compactRoot.currentPillTask ? Kirigami.Theme.textColor : "#34d399")
                    elide: Text.ElideRight
                    Layout.maximumWidth: 215
                    Layout.alignment: Qt.AlignVCenter
                }

                // Part 2: Dynamic Context Pill (overdue / due countdown / estimate / tag / P1)
                Rectangle {
                    visible: compactRoot.contextBadgeText !== ""
                    implicitHeight: 22
                    implicitWidth: ctxBadgeLbl.implicitWidth + 12
                    radius: 6
                    color: {
                        if (compactRoot.contextBadgeKind === "overdue" || compactRoot.contextBadgeKind === "urgent") {
                            return Qt.rgba(0.94, 0.27, 0.27, 0.18);
                        }
                        if (compactRoot.contextBadgeKind === "soon") {
                            return Qt.rgba(0.98, 0.45, 0.09, 0.18);
                        }
                        if (compactRoot.contextBadgeKind === "due") {
                            return Qt.rgba(0.23, 0.51, 0.96, 0.18);
                        }
                        return Qt.rgba(1, 1, 1, 0.07);
                    }
                    border.width: 1
                    border.color: {
                        if (compactRoot.contextBadgeKind === "overdue" || compactRoot.contextBadgeKind === "urgent") {
                            return Qt.rgba(0.94, 0.27, 0.27, 0.4);
                        }
                        if (compactRoot.contextBadgeKind === "soon") {
                            return Qt.rgba(0.98, 0.45, 0.09, 0.4);
                        }
                        if (compactRoot.contextBadgeKind === "due") {
                            return Qt.rgba(0.23, 0.51, 0.96, 0.35);
                        }
                        return Qt.rgba(1, 1, 1, 0.12);
                    }
                    Layout.alignment: Qt.AlignVCenter

                    PlasmaComponents.Label {
                        id: ctxBadgeLbl
                        anchors.centerIn: parent
                        text: compactRoot.contextBadgeText
                        font.pixelSize: 11
                        font.bold: true
                        color: {
                            if (compactRoot.contextBadgeKind === "overdue" || compactRoot.contextBadgeKind === "urgent") {
                                return "#fca5a5";
                            }
                            if (compactRoot.contextBadgeKind === "soon") {
                                return "#fdba74";
                            }
                            if (compactRoot.contextBadgeKind === "due") {
                                return "#93c5fd";
                            }
                            return Kirigami.Theme.textColor;
                        }
                        opacity: compactRoot.contextBadgeKind === "meta" ? 0.8 : 1.0
                    }
                }

                // Part 3: Active Counter Badge (or index/total while wheel-scrolling)
                Rectangle {
                    visible: root.daemonOnline && root.pendingCount > 0
                    implicitHeight: 22
                    implicitWidth: Math.max(22, countPillLbl.implicitWidth + 12)
                    radius: 6
                    color: root.overdueCount > 0
                        ? Qt.rgba(0.94, 0.27, 0.27, 0.22)
                        : Qt.rgba(0.23, 0.51, 0.96, 0.2)
                    border.width: 1
                    border.color: root.overdueCount > 0
                        ? Qt.rgba(0.94, 0.27, 0.27, 0.45)
                        : Qt.rgba(0.23, 0.51, 0.96, 0.4)
                    Layout.alignment: Qt.AlignVCenter

                    PlasmaComponents.Label {
                        id: countPillLbl
                        anchors.centerIn: parent
                        text: root.pillTaskIndex > 0 && root.activePillTasks.length > 1
                            ? ((root.pillTaskIndex + 1) + "/" + root.pendingCount)
                            : String(root.pendingCount)
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                        color: root.overdueCount > 0 ? "#fca5a5" : "#93c5fd"
                    }
                }
            }
        }
    }

    // ==========================================
    // FULL REPRESENTATION (Popout Bento Dashboard)
    // ==========================================
    fullRepresentation: Item {
        id: fullRoot
        implicitWidth: 560
        implicitHeight: 720
        Component.onCompleted: root.fullRootItem = fullRoot
        Component.onDestruction: {
            if (root.fullRootItem === fullRoot) root.fullRootItem = null;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            HeaderBar {
                app: root
            }

            // VIEW 1: TASKS
            ColumnLayout {
                visible: root.currentView === "tasks"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                TaskFormCard {
                    visible: root.isFormOpen
                    app: root
                }

                // Filter, Sort & Search Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "active", label: "Active" },
                            { key: "today", label: "Today" },
                            { key: "completed", label: "Done" },
                            { key: "all", label: "All" }
                        ]
                        delegate: Rectangle {
                            implicitHeight: 28
                            implicitWidth: tabLabel.implicitWidth + 14
                            radius: 6
                            color: root.activeFilter === modelData.key ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: root.activeFilter === modelData.key ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

                            PlasmaComponents.Label {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 12
                                font.bold: root.activeFilter === modelData.key
                                opacity: root.activeFilter === modelData.key ? 1.0 : 0.7
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeFilter = modelData.key;
                                    root.fetchTasks();
                                }
                            }
                        }
                    }

                    // Sort Toggle Button (Prio / Due)
                    Rectangle {
                        implicitHeight: 28
                        implicitWidth: sortLbl.implicitWidth + 12
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)

                        PlasmaComponents.Label {
                            id: sortLbl
                            anchors.centerIn: parent
                            text: root.sortMode === "due" ? "⇅ Due" : "⇅ Prio"
                            font.pixelSize: 11
                            opacity: 0.75
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.sortMode = (root.sortMode === "priority") ? "due" : "priority";
                                root.fetchTasks();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Search Box
                    Rectangle {
                        Layout.preferredWidth: 150
                        height: 28
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.24)
                        border.width: 1
                        border.color: searchInput.activeFocus ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.1)

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 12
                            color: Kirigami.Theme.textColor
                            clip: true
                            onTextChanged: root.searchQuery = text.toLowerCase()

                            Text {
                                text: "Search..."
                                font.pixelSize: 12
                                color: Kirigami.Theme.textColor
                                opacity: 0.4
                                visible: !searchInput.text && !searchInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Tag Filter Chips Row (only shown when active tags exist)
                Flow {
                    visible: root.tagsList.length > 0
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        visible: root.activeTag !== ""
                        implicitHeight: 22
                        implicitWidth: clearTagLbl.implicitWidth + 12
                        radius: 4
                        color: Qt.rgba(0.94, 0.27, 0.27, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(0.94, 0.27, 0.27, 0.35)

                        PlasmaComponents.Label {
                            id: clearTagLbl
                            anchors.centerIn: parent
                            text: "✕ All tags"
                            font.pixelSize: 11
                            color: "#fca5a5"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTag = "";
                                root.fetchTasks();
                            }
                        }
                    }

                    Repeater {
                        model: root.tagsList
                        delegate: Rectangle {
                            implicitHeight: 22
                            implicitWidth: tagChipLbl.implicitWidth + 12
                            radius: 4
                            property bool isActive: root.activeTag === modelData.name
                            color: isActive ? Qt.rgba(0.23, 0.51, 0.96, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: isActive ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.1)

                            PlasmaComponents.Label {
                                id: tagChipLbl
                                anchors.centerIn: parent
                                text: "#" + modelData.name + " (" + modelData.count + ")"
                                font.pixelSize: 11
                                font.bold: isActive
                                color: isActive ? "#93c5fd" : Kirigami.Theme.textColor
                                opacity: isActive ? 1.0 : 0.75
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeTag = isActive ? "" : modelData.name;
                                    root.fetchTasks();
                                }
                            }
                        }
                    }
                }

                // Task Cards ListView (hidden when empty so Empty State gets full area)
                ListView {
                    id: taskListView
                    visible: count > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10
                    interactive: root.dragSourceIndex === -1
                    cacheBuffer: root.dragSourceIndex !== -1 ? Math.max(4000, contentHeight) : 320

                    function scrollDuringDrag(angleDeltaY) {
                        if (root.dragSourceIndex === -1 || !angleDeltaY) return;
                        var maxY = Math.max(0, taskListView.contentHeight - taskListView.height);
                        if (maxY <= 0) return;
                        var oldY = taskListView.contentY;
                        var newY = Math.max(0, Math.min(maxY, oldY - angleDeltaY * 0.45));
                        var delta = newY - oldY;
                        if (Math.abs(delta) < 0.5) return;
                        taskListView.contentY = newY;
                        if (root.draggedCardItem) {
                            var minCardY = -Math.round(root.draggedCardItem.height * 0.4);
                            var maxCardY = Math.max(0, taskListView.contentHeight - Math.round(root.draggedCardItem.height * 0.6));
                            root.draggedCardItem.y = Math.max(minCardY, Math.min(maxCardY, root.draggedCardItem.y + delta));
                            if (root.draggedCardItem.syncDragTarget) {
                                root.draggedCardItem.syncDragTarget();
                            }
                        }
                    }

                    WheelHandler {
                        id: dragScrollWheel
                        enabled: root.dragSourceIndex !== -1
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            taskListView.scrollDuringDrag(event.angleDelta.y);
                        }
                    }

                    function updateDragTarget(cardIndex, cursorY, cardY, cardHeight) {
                        var modelArr = taskListView.model;
                        if (!modelArr || modelArr.length === 0) return;

                        var lastActiveIdx = -1;
                        for (var k = 0; k < modelArr.length; ++k) {
                            if (modelArr[k] && !modelArr[k].completed) {
                                lastActiveIdx = k;
                            }
                        }
                        if (lastActiveIdx < 0) return;

                        if (cursorY <= 8 || cardY <= 4) {
                            root.dragTargetIndex = 0;
                            return;
                        }
                        if (cursorY >= taskListView.contentHeight - 8 || (cardY + cardHeight) >= taskListView.contentHeight - 4) {
                            root.dragTargetIndex = lastActiveIdx;
                            return;
                        }

                        var probeUp = Math.min(cursorY, cardY + 10);
                        var probeDown = Math.max(cursorY, cardY + cardHeight - 10);

                        var target = cardIndex;
                        for (var i = 0; i <= lastActiveIdx; ++i) {
                            var it = taskListView.itemAtIndex(i);
                            if (!it || !it.taskData || it.taskData.completed) continue;
                            var mid = it.y + it.height / 2;
                            if (cardIndex < i && probeDown > mid) {
                                target = i;
                            } else if (cardIndex > i && probeUp < mid && i < target) {
                                target = i;
                            }
                        }
                        root.dragTargetIndex = target;
                    }

                    model: {
                        if (!root.searchQuery) return root.tasksList;
                        return root.tasksList.filter(function(t) {
                            return t.title.toLowerCase().indexOf(root.searchQuery) !== -1 ||
                                   (t.tag && t.tag.toLowerCase().indexOf(root.searchQuery) !== -1) ||
                                   (t.notes && t.notes.toLowerCase().indexOf(root.searchQuery) !== -1);
                        });
                    }

                    delegate: TaskCard {
                        required property var modelData
                        required property int index
                        width: taskListView.width
                        app: root
                        taskData: modelData
                        itemIndex: index
                        listViewRef: taskListView
                    }
                }

                // Empty State
                Item {
                    visible: taskListView.count === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        PlasmaComponents.Label {
                            text: root.daemonOnline ? "✨" : "🔌"
                            font.pixelSize: 34
                            Layout.alignment: Qt.AlignHCenter
                        }

                        PlasmaComponents.Label {
                            text: root.daemonOnline
                                ? (root.searchQuery || root.activeTag ? "No matching tasks." : "All clear! No tasks right now.")
                                : "TaskFlow daemon is offline."
                            font.pixelSize: 14
                            opacity: 0.6
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // VIEW 2: CALENDAR
            CalendarView {
                visible: root.currentView === "calendar"
                app: root
            }

            // VIEW 3: SETTINGS
            SettingsView {
                visible: root.currentView === "settings"
                app: root
            }
        }

        // Floating Priority Picker Overlay
        MouseArea {
            anchors.fill: parent
            z: 998
            visible: root.prioMenuVisible
            onClicked: root.prioMenuVisible = false
        }

        Rectangle {
            id: priorityPopover
            z: 999
            visible: root.prioMenuVisible
            x: root.prioMenuX
            y: root.prioMenuY
            width: 132
            height: prioCol.implicitHeight + 10
            radius: 8
            color: "#181b22"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)

            ColumnLayout {
                id: prioCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                spacing: 3

                Repeater {
                    model: [
                        { val: 1, label: "Urgent", color: "#ef4444" },
                        { val: 2, label: "High", color: "#f97316" },
                        { val: 3, label: "Medium", color: "#3b82f6" },
                        { val: 4, label: "Low", color: "#64748b" }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        radius: 5
                        property bool isCurrent: root.prioMenuCurrent === modelData.val
                        color: prioOptHover.hovered
                            ? Qt.rgba(1, 1, 1, 0.1)
                            : (isCurrent ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                        HoverHandler { id: prioOptHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: modelData.color
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.pixelSize: 12
                                font.bold: isCurrent
                                color: isCurrent ? modelData.color : Kirigami.Theme.textColor
                                opacity: isCurrent ? 1.0 : 0.88
                            }

                            PlasmaComponents.Label {
                                visible: isCurrent
                                text: "✓"
                                font.pixelSize: 11
                                font.bold: true
                                color: modelData.color
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setTaskPriority(root.prioMenuTaskId, modelData.val)
                        }
                    }
                }
            }
        }
    }
}
