import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: formRoot
    required property var app

    Layout.fillWidth: true
    implicitHeight: formCol.implicitHeight + 24
    clip: true
    radius: 8
    color: Qt.rgba(1, 1, 1, 0.04)
    border.width: 1
    border.color: app.editingTaskId > 0 ? Qt.rgba(0.98, 0.45, 0.09, 0.35) : Qt.rgba(1, 1, 1, 0.12)

    property int tagSuggestionIdx: -1

    property var tagSuggestions: {
        var source = (app.allTagsList && app.allTagsList.length > 0)
            ? app.allTagsList
            : (app.tagsList || []).map(function(t) { return t.name; });
        var q = (app.formTag || "").trim().toLowerCase();
        if (!source || source.length === 0) return [];
        if (q === "") return source.slice(0, 6);

        var prefixMatches = [];
        var substrMatches = [];
        for (var i = 0; i < source.length; ++i) {
            var name = source[i];
            var low = name.toLowerCase();
            if (low.indexOf(q) === 0) {
                prefixMatches.push(name);
            } else if (low.indexOf(q) > 0) {
                substrMatches.push(name);
            }
        }
        return prefixMatches.concat(substrMatches).slice(0, 6);
    }

    property string tagTabCandidate: {
        if (!tagSuggestions || tagSuggestions.length === 0) return "";
        if (tagSuggestionIdx >= 0 && tagSuggestionIdx < tagSuggestions.length) {
            return tagSuggestions[tagSuggestionIdx];
        }
        var q = (app.formTag || "").trim();
        if (q !== "" && tagSuggestions[0] !== q) {
            return tagSuggestions[0];
        }
        return "";
    }

    function applyTagSuggestion(tagName) {
        if (!tagName) return;
        app.formTag = tagName;
        inputTag.text = tagName;
        inputTag.cursorPosition = tagName.length;
        formRoot.tagSuggestionIdx = -1;
    }

    function addSubtaskFromInput() {
        if (app.formSubtaskInput.trim()) {
            var list = app.formSubtasks.slice();
            list.push(app.formSubtaskInput.trim());
            app.formSubtasks = list;
            app.formSubtaskInput = "";
        }
    }

    function focusTitle() {
        focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 20
        repeat: false
        onTriggered: {
            if (formRoot.visible) {
                inputTitle.forceActiveFocus(Qt.TabFocusReason);
                inputTitle.cursorPosition = inputTitle.text.length;
            }
        }
    }

    Connections {
        target: formRoot.app
        function onFormFocusTokenChanged() {
            formRoot.focusTitle();
        }
    }

    onVisibleChanged: {
        if (visible && !app.formTitle) {
            focusTitle();
        }
    }

    ColumnLayout {
        id: formCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        // Form Header (Create vs Edit)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PlasmaComponents.Label {
                text: app.editingTaskId > 0 ? ("Editing Task #" + app.editingTaskId) : "New Task"
                font.pixelSize: 13
                font.bold: true
                color: app.editingTaskId > 0 ? "#fb923c" : "#60a5fa"
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.Label {
                text: "Tab / Shift+Tab • Enter to act"
                font.pixelSize: 11
                opacity: 0.5
            }
        }

        // Row 1: Title Input
        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            height: 34
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.28)
            border.width: inputTitle.activeFocus ? 2 : 1
            border.color: inputTitle.activeFocus ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.12)

            TextInput {
                id: inputTitle
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 13
                color: Kirigami.Theme.textColor
                selectionColor: "#3b82f6"
                clip: true
                activeFocusOnTab: true
                KeyNavigation.backtab: submitBtn
                text: app.formTitle
                onTextChanged: {
                    if (app.formTitle !== text) app.formTitle = text;
                }
                Keys.onReturnPressed: app.submitTaskForm()
                Keys.onEnterPressed: app.submitTaskForm()

                Text {
                    text: "Task title..."
                    font.pixelSize: 13
                    color: Kirigami.Theme.textColor
                    opacity: 0.35
                    visible: !inputTitle.text && !inputTitle.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Row 2: Due Date Input + Pick Day Button
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                height: 32
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.24)
                border.width: inputDue.activeFocus ? 2 : 1
                border.color: inputDue.activeFocus ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.12)

                TextInput {
                    id: inputDue
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 12
                    font.family: "Monospace"
                    color: Kirigami.Theme.textColor
                    clip: true
                    activeFocusOnTab: true
                    text: app.formDueDate
                    onTextChanged: {
                        if (app.formDueDate !== text) app.formDueDate = text;
                    }
                    Keys.onReturnPressed: app.submitTaskForm()
                    Keys.onEnterPressed: app.submitTaskForm()

                    Text {
                        text: "Due: YYYY-MM-DD HH:MM or 1405/09/01 18:00"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        opacity: 0.35
                        visible: !inputDue.text && !inputDue.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Clear due button (if non-empty)
            Rectangle {
                id: clearDueBtn
                visible: app.formDueDate !== ""
                activeFocusOnTab: visible
                implicitHeight: 32
                implicitWidth: 32
                radius: 5
                color: activeFocus ? Qt.rgba(0.94, 0.27, 0.27, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                border.width: activeFocus ? 2 : 1
                border.color: activeFocus ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.12)

                Keys.onReturnPressed: app.formDueDate = ""
                Keys.onEnterPressed: app.formDueDate = ""
                Keys.onSpacePressed: app.formDueDate = ""

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    opacity: 0.7
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: app.formDueDate = ""
                }
            }

            // Pick Day from Calendar button
            Rectangle {
                id: pickDayBtn
                activeFocusOnTab: true
                implicitHeight: 32
                implicitWidth: pickBtnLbl.implicitWidth + 16
                radius: 5
                color: (pickHover.hovered || activeFocus) ? Qt.rgba(0.23, 0.51, 0.96, 0.28) : Qt.rgba(0.23, 0.51, 0.96, 0.16)
                border.width: activeFocus ? 2 : 1
                border.color: activeFocus ? "#93c5fd" : Qt.rgba(0.23, 0.51, 0.96, 0.38)

                function triggerPick() {
                    app.pickingDateForForm = true;
                    app.currentView = "calendar";
                    app.fetchCalendarTasks();
                }

                Keys.onReturnPressed: triggerPick()
                Keys.onEnterPressed: triggerPick()
                Keys.onSpacePressed: triggerPick()

                HoverHandler { id: pickHover }

                PlasmaComponents.Label {
                    id: pickBtnLbl
                    anchors.centerIn: parent
                    text: "📅 Pick Day"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#60a5fa"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pickDayBtn.triggerPick()
                }
            }
        }

        // Row 3: Quick Due Presets & Quick Time Chips (wrapping Flow prevents any overflow)
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { label: "+2h", hours: 2 },
                    { label: "+6h", hours: 6 },
                    { label: "Tomorrow", hours: 24 }
                ]
                delegate: Rectangle {
                    activeFocusOnTab: true
                    implicitHeight: 24
                    implicitWidth: presetLbl.implicitWidth + 14
                    radius: 4
                    color: activeFocus ? Qt.rgba(0.23, 0.51, 0.96, 0.22) : Qt.rgba(1, 1, 1, 0.07)
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.12)

                    Keys.onReturnPressed: app.setQuickDue(modelData.hours)
                    Keys.onEnterPressed: app.setQuickDue(modelData.hours)
                    Keys.onSpacePressed: app.setQuickDue(modelData.hours)

                    PlasmaComponents.Label {
                        id: presetLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: app.setQuickDue(modelData.hours)
                    }
                }
            }

            // Subtle divider spacer
            Item { width: 4; height: 24 }

            Repeater {
                model: ["09:00", "14:00", "18:00", "21:00", "23:59"]
                delegate: Rectangle {
                    activeFocusOnTab: true
                    implicitHeight: 24
                    implicitWidth: timeLbl.implicitWidth + 12
                    radius: 4
                    color: activeFocus ? Qt.rgba(0.23, 0.51, 0.96, 0.26) : Qt.rgba(0.23, 0.51, 0.96, 0.1)
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? "#93c5fd" : Qt.rgba(0.23, 0.51, 0.96, 0.25)

                    Keys.onReturnPressed: app.setQuickTime(modelData)
                    Keys.onEnterPressed: app.setQuickTime(modelData)
                    Keys.onSpacePressed: app.setQuickTime(modelData)

                    PlasmaComponents.Label {
                        id: timeLbl
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 11
                        font.family: "Monospace"
                        color: "#93c5fd"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: app.setQuickTime(modelData)
                    }
                }
            }
        }

        // Row 4: Tag + Estimate + Priority
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Tag Input with inline Tab completion hint
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                height: 30
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.24)
                border.width: inputTag.activeFocus ? 2 : 1
                border.color: inputTag.activeFocus ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.12)

                TextInput {
                    id: inputTag
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: tagHintBadge.visible ? (tagHintBadge.width + 12) : 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 12
                    color: Kirigami.Theme.textColor
                    clip: true
                    activeFocusOnTab: true
                    text: app.formTag
                    onTextChanged: {
                        if (app.formTag !== text) app.formTag = text;
                        formRoot.tagSuggestionIdx = -1;
                    }

                    Keys.onTabPressed: (event) => {
                        if (formRoot.tagTabCandidate !== "") {
                            formRoot.applyTagSuggestion(formRoot.tagTabCandidate);
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }

                    Keys.onBacktabPressed: (event) => {
                        event.accepted = false;
                    }

                    Keys.onDownPressed: (event) => {
                        if (formRoot.tagSuggestions.length > 0) {
                            formRoot.tagSuggestionIdx = (formRoot.tagSuggestionIdx + 1) % formRoot.tagSuggestions.length;
                            event.accepted = true;
                        }
                    }

                    Keys.onUpPressed: (event) => {
                        if (formRoot.tagSuggestions.length > 0) {
                            formRoot.tagSuggestionIdx = (formRoot.tagSuggestionIdx <= 0)
                                ? (formRoot.tagSuggestions.length - 1)
                                : (formRoot.tagSuggestionIdx - 1);
                            event.accepted = true;
                        }
                    }

                    Keys.onReturnPressed: (event) => {
                        if (formRoot.tagSuggestionIdx >= 0 && formRoot.tagSuggestionIdx < formRoot.tagSuggestions.length) {
                            formRoot.applyTagSuggestion(formRoot.tagSuggestions[formRoot.tagSuggestionIdx]);
                            event.accepted = true;
                        } else {
                            app.submitTaskForm();
                        }
                    }

                    Keys.onEnterPressed: (event) => {
                        if (formRoot.tagSuggestionIdx >= 0 && formRoot.tagSuggestionIdx < formRoot.tagSuggestions.length) {
                            formRoot.applyTagSuggestion(formRoot.tagSuggestions[formRoot.tagSuggestionIdx]);
                            event.accepted = true;
                        } else {
                            app.submitTaskForm();
                        }
                    }

                    Text {
                        text: "Tag (e.g. دانشگاه)"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        opacity: 0.35
                        visible: !inputTag.text && !inputTag.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Inline Tab completion badge
                Rectangle {
                    id: tagHintBadge
                    visible: inputTag.activeFocus && formRoot.tagTabCandidate !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: Math.min(tagHintLbl.implicitWidth + 10, 120)
                    radius: 3
                    color: Qt.rgba(0.23, 0.51, 0.96, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(0.23, 0.51, 0.96, 0.45)

                    PlasmaComponents.Label {
                        id: tagHintLbl
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: "Tab ↹ " + formRoot.tagTabCandidate
                        font.pixelSize: 10
                        font.bold: true
                        color: "#93c5fd"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: formRoot.applyTagSuggestion(formRoot.tagTabCandidate)
                    }
                }
            }

            // Estimate Input
            Rectangle {
                Layout.preferredWidth: 74
                height: 30
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.24)
                border.width: inputEst.activeFocus ? 2 : 1
                border.color: inputEst.activeFocus ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.12)

                TextInput {
                    id: inputEst
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 12
                    color: Kirigami.Theme.textColor
                    clip: true
                    activeFocusOnTab: true
                    text: app.formEstimate
                    onTextChanged: {
                        if (app.formEstimate !== text) app.formEstimate = text;
                    }
                    Keys.onReturnPressed: app.submitTaskForm()
                    Keys.onEnterPressed: app.submitTaskForm()

                    Text {
                        text: "Est (1h)"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        opacity: 0.35
                        visible: !inputEst.text && !inputEst.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Priority Chips P1..P4
            RowLayout {
                spacing: 4
                Repeater {
                    model: [
                        { p: 1, label: "P1" },
                        { p: 2, label: "P2" },
                        { p: 3, label: "P3" },
                        { p: 4, label: "P4" }
                    ]
                    delegate: Rectangle {
                        activeFocusOnTab: true
                        implicitHeight: 30
                        implicitWidth: 32
                        radius: 5
                        color: app.formPriority === modelData.p
                            ? app.getPriorityColor(modelData.p)
                            : (activeFocus ? Qt.rgba(0.23, 0.51, 0.96, 0.2) : Qt.rgba(1, 1, 1, 0.06))
                        border.width: activeFocus ? 2 : 1
                        border.color: activeFocus
                            ? "#ffffff"
                            : (app.formPriority === modelData.p ? app.getPriorityColor(modelData.p) : Qt.rgba(1, 1, 1, 0.12))

                        Keys.onReturnPressed: app.formPriority = modelData.p
                        Keys.onEnterPressed: app.formPriority = modelData.p
                        Keys.onSpacePressed: app.formPriority = modelData.p

                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 11
                            font.bold: true
                            color: app.formPriority === modelData.p ? "#ffffff" : Kirigami.Theme.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: app.formPriority = modelData.p
                        }
                    }
                }
            }
        }

        // Tag Autocomplete Suggestions Bar (shown while Tag input is focused & tags exist)
        Flow {
            visible: inputTag.activeFocus && formRoot.tagSuggestions.length > 0
            Layout.fillWidth: true
            spacing: 5

            PlasmaComponents.Label {
                text: "Tags:"
                font.pixelSize: 10
                opacity: 0.55
                height: 20
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: formRoot.tagSuggestions
                delegate: Rectangle {
                    implicitHeight: 20
                    implicitWidth: sugLbl.implicitWidth + 12
                    radius: 4
                    property bool isHighlighted: (formRoot.tagSuggestionIdx === index) || (formRoot.tagSuggestionIdx < 0 && index === 0 && app.formTag.trim() !== "")
                    color: isHighlighted ? Qt.rgba(0.23, 0.51, 0.96, 0.28) : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: isHighlighted ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.12)

                    PlasmaComponents.Label {
                        id: sugLbl
                        anchors.centerIn: parent
                        text: "#" + modelData
                        font.pixelSize: 10
                        font.bold: isHighlighted
                        color: isHighlighted ? "#93c5fd" : Kirigami.Theme.textColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: formRoot.applyTagSuggestion(modelData)
                    }
                }
            }
        }

        // Row 5: Recurrence + Notes Input
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PlasmaComponents.Label {
                text: "Repeat:"
                font.pixelSize: 11
                opacity: 0.6
            }

            Repeater {
                model: [
                    { key: "", label: "Once" },
                    { key: "daily", label: "Daily" },
                    { key: "weekly", label: "Weekly" },
                    { key: "monthly", label: "Monthly" }
                ]
                delegate: Rectangle {
                    activeFocusOnTab: true
                    implicitHeight: 24
                    implicitWidth: repLbl.implicitWidth + 12
                    radius: 4
                    color: app.formRecurrence === modelData.key
                        ? Qt.rgba(0.23, 0.51, 0.96, 0.25)
                        : (activeFocus ? Qt.rgba(0.23, 0.51, 0.96, 0.16) : Qt.rgba(1, 1, 1, 0.05))
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus
                        ? "#93c5fd"
                        : (app.formRecurrence === modelData.key ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.1))

                    Keys.onReturnPressed: app.formRecurrence = modelData.key
                    Keys.onEnterPressed: app.formRecurrence = modelData.key
                    Keys.onSpacePressed: app.formRecurrence = modelData.key

                    PlasmaComponents.Label {
                        id: repLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 11
                        font.bold: app.formRecurrence === modelData.key
                        color: app.formRecurrence === modelData.key ? "#93c5fd" : Kirigami.Theme.textColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: app.formRecurrence = modelData.key
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                height: 26
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.22)
                border.width: inputNotes.activeFocus ? 2 : 1
                border.color: inputNotes.activeFocus ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.1)

                TextInput {
                    id: inputNotes
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 12
                    color: Kirigami.Theme.textColor
                    clip: true
                    activeFocusOnTab: true
                    text: app.formNotes
                    onTextChanged: {
                        if (app.formNotes !== text) app.formNotes = text;
                    }
                    Keys.onReturnPressed: app.submitTaskForm()
                    Keys.onEnterPressed: app.submitTaskForm()

                    Text {
                        text: "Notes (optional)..."
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        opacity: 0.35
                        visible: !inputNotes.text && !inputNotes.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Row 6: Subtasks Input (Create mode only; Edit mode manages subtasks inline on card)
        RowLayout {
            visible: app.editingTaskId <= 0
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                height: 28
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.24)
                border.width: inputSubtask.activeFocus ? 2 : 1
                border.color: inputSubtask.activeFocus ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.1)

                TextInput {
                    id: inputSubtask
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 12
                    color: Kirigami.Theme.textColor
                    clip: true
                    activeFocusOnTab: app.editingTaskId <= 0
                    text: app.formSubtaskInput
                    onTextChanged: {
                        if (app.formSubtaskInput !== text) app.formSubtaskInput = text;
                    }
                    onAccepted: formRoot.addSubtaskFromInput()

                    Text {
                        text: "+ Add subtask item (press Enter)"
                        font.pixelSize: 11
                        color: Kirigami.Theme.textColor
                        opacity: 0.35
                        visible: !inputSubtask.text && !inputSubtask.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                id: addSubBtn
                activeFocusOnTab: app.editingTaskId <= 0
                implicitHeight: 28
                implicitWidth: 66
                radius: 5
                color: activeFocus ? Qt.rgba(0.23, 0.51, 0.96, 0.24) : Qt.rgba(1, 1, 1, 0.1)
                border.width: activeFocus ? 2 : 1
                border.color: activeFocus ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.12)

                Keys.onReturnPressed: formRoot.addSubtaskFromInput()
                Keys.onEnterPressed: formRoot.addSubtaskFromInput()
                Keys.onSpacePressed: formRoot.addSubtaskFromInput()

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: "Add Sub"
                    font.pixelSize: 11
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: formRoot.addSubtaskFromInput()
                }
            }
        }

        // Subtask Preview Chips
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: app.editingTaskId <= 0 && app.formSubtasks.length > 0

            Repeater {
                model: app.formSubtasks
                delegate: Rectangle {
                    implicitHeight: 22
                    implicitWidth: subRow.implicitWidth + 14
                    radius: 4
                    color: Qt.rgba(0.23, 0.51, 0.96, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(0.23, 0.51, 0.96, 0.35)

                    RowLayout {
                        id: subRow
                        anchors.centerIn: parent
                        spacing: 4
                        PlasmaComponents.Label {
                            text: "• " + modelData
                            font.pixelSize: 11
                            color: "#93c5fd"
                        }
                        PlasmaComponents.Label {
                            text: "✕"
                            font.pixelSize: 10
                            color: "#fca5a5"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var copy = app.formSubtasks.slice();
                                    copy.splice(index, 1);
                                    app.formSubtasks = copy;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Error Banner
        Rectangle {
            visible: app.formError !== ""
            Layout.fillWidth: true
            implicitHeight: errLbl.implicitHeight + 10
            radius: 5
            color: Qt.rgba(0.94, 0.27, 0.27, 0.18)
            border.width: 1
            border.color: Qt.rgba(0.94, 0.27, 0.27, 0.45)

            PlasmaComponents.Label {
                id: errLbl
                anchors.fill: parent
                anchors.margins: 5
                text: app.formError
                font.pixelSize: 11
                color: "#fca5a5"
                wrapMode: Text.WordWrap
            }
        }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: cancelBtn
                activeFocusOnTab: true
                implicitHeight: 34
                implicitWidth: 82
                radius: 6
                color: activeFocus ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                border.width: activeFocus ? 2 : 1
                border.color: activeFocus ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.12)

                Keys.onReturnPressed: app.closeTaskForm()
                Keys.onEnterPressed: app.closeTaskForm()
                Keys.onSpacePressed: app.closeTaskForm()

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: 13
                    opacity: 0.85
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: app.closeTaskForm()
                }
            }

            Rectangle {
                id: submitBtn
                activeFocusOnTab: true
                KeyNavigation.tab: inputTitle
                Layout.fillWidth: true
                height: 34
                radius: 6
                color: app.editingTaskId > 0
                    ? (activeFocus ? "#f97316" : "#ea580c")
                    : (activeFocus ? "#3b82f6" : "#2563eb")
                border.width: activeFocus ? 2 : 0
                border.color: "#ffffff"

                Keys.onReturnPressed: app.submitTaskForm()
                Keys.onEnterPressed: app.submitTaskForm()
                Keys.onSpacePressed: app.submitTaskForm()

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: app.editingTaskId > 0 ? "Save Changes" : "Create Task"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: app.submitTaskForm()
                }
            }
        }
    }
}
