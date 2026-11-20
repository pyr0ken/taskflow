#!/usr/bin/env python3
"""
TaskFlow Daemon for KDE Plasma 6
Provides local SQLite (WAL) storage, threaded HTTP REST API, interactive deadline notifications,
smart Jalali/Gregorian/relative date parsing, recurring tasks, and user settings management.
"""

import calendar
import json
import os
import re
import sqlite3
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = 28490
DATA_DIR = os.path.expanduser("~/.local/share/plasma-taskflow")
DB_PATH = os.path.join(DATA_DIR, "tasks.db")

os.makedirs(DATA_DIR, exist_ok=True)

FA_MONTHS = [
    "", "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
    "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"
]
FA_WEEKDAYS = {
    5: "شنبه",
    6: "یک\u200cشنبه",
    0: "دوشنبه",
    1: "سه\u200cشنبه",
    2: "چهارشنبه",
    3: "پنج\u200cشنبه",
    4: "جمعه",
}

PRIORITY_MAP = {
    1: {"name": "Urgent", "color": "#ef4444"},
    2: {"name": "High", "color": "#f97316"},
    3: {"name": "Medium", "color": "#3b82f6"},
    4: {"name": "Low", "color": "#64748b"},
}

ACTIVE_NOTIF_THREADS = set()
NOTIF_LOCK = threading.Lock()


def g2j(gy, gm, gd):
    """Gregorian to Jalali date conversion (Kazem/Pournader)."""
    g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    if gy > 1600:
        jy = 979
        gy -= 1600
    else:
        jy = 0
        gy -= 621
    gy2 = gy if gm > 2 else gy - 1
    days = (
        365 * gy
        + (gy2 + 4) // 4
        - (gy2 + 100) // 100
        + (gy2 + 400) // 400
        - 80
        + gd
        + g_d_m[gm - 1]
    )
    jy += 33 * (days // 12053)
    days %= 12053
    jy += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        jy += (days - 1) // 365
        days = (days - 1) % 365
    if days < 186:
        jm = 1 + days // 31
        jd = 1 + days % 31
    else:
        jm = 7 + (days - 186) // 30
        jd = 1 + (days - 186) % 30
    return jy, jm, jd


def j2g(jy, jm, jd):
    """Jalali to Gregorian date conversion."""
    if jy > 979:
        gy = 1600
        jy -= 979
    else:
        gy = 621
    days = (
        365 * jy
        + (jy // 33) * 8
        + ((jy % 33) + 3) // 4
        + 78
        + jd
        + ((jm - 1) * 31 if jm < 7 else 186 + (jm - 7) * 30)
    )
    gy += 400 * (days // 146097)
    days %= 146097
    if days > 36524:
        days -= 1
        gy += 100 * (days // 36524)
        days %= 36524
        if days >= 365:
            days += 1
    gy += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        gy += (days - 1) // 365
        days = (days - 1) % 365
    gd = days + 1
    sal_a = [
        0,
        31,
        29 if (gy % 4 == 0 and gy % 100 != 0) or (gy % 400 == 0) else 28,
        31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
    ]
    gm = 0
    while gm < 13 and gd > sal_a[gm]:
        gd -= sal_a[gm]
        gm += 1
    return gy, gm, gd


def parse_due_input(raw_due):
    """
    Parse flexible due date inputs into canonical 'YYYY-MM-DD' or 'YYYY-MM-DD HH:MM'.
    Supports:
      - Empty string -> ''
      - Relative: '+30m', '+2h', '+3d'
      - Keywords: 'today', 'today 18:00', 'tomorrow', 'tomorrow 09:30'
      - Jalali: '1405-09-01', '1405/09/01 18:00' (year 1300..1599 auto-detected)
      - Gregorian: '2026-11-20', '2026-11-20 18:00', '2026/11/20T18:00'
    """
    if raw_due is None:
        return ""
    text = str(raw_due).strip()
    if not text:
        return ""

    # Convert Persian/Arabic digits if any
    persian_digits = str.maketrans("۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩", "01234567890123456789")
    text = text.translate(persian_digits)
    lower = text.lower()
    now = datetime.now()

    # Relative +Nm / +Nh / +Nd
    m_rel = re.fullmatch(r"\+(\d+)\s*([mhd])", lower)
    if m_rel:
        val = int(m_rel.group(1))
        unit = m_rel.group(2)
        if unit == "m":
            dt = now + timedelta(minutes=val)
        elif unit == "h":
            dt = now + timedelta(hours=val)
        else:
            dt = now + timedelta(days=val)
        return dt.strftime("%Y-%m-%d %H:%M")

    # today / tomorrow [HH:MM]
    m_kw = re.fullmatch(r"(today|tomorrow)(?:\s+(\d{1,2}):(\d{2}))?", lower)
    if m_kw:
        base = now if m_kw.group(1) == "today" else (now + timedelta(days=1))
        if m_kw.group(2) is not None:
            hh, mm = int(m_kw.group(2)), int(m_kw.group(3))
            dt = base.replace(hour=hh, minute=mm, second=0, microsecond=0)
            return dt.strftime("%Y-%m-%d %H:%M")
        return base.strftime("%Y-%m-%d")

    # Date [T| ] [HH:MM[:SS]]
    m_dt = re.fullmatch(
        r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?",
        text,
    )
    if m_dt:
        y, m, d = int(m_dt.group(1)), int(m_dt.group(2)), int(m_dt.group(3))
        if 1300 <= y <= 1599:
            y, m, d = j2g(y, m, d)
        # Validate date
        datetime(y, m, d)
        if m_dt.group(4) is not None:
            hh, mm = int(m_dt.group(4)), int(m_dt.group(5))
            if not (0 <= hh <= 23 and 0 <= mm <= 59):
                raise ValueError("Invalid time")
            return f"{y:04d}-{m:02d}-{d:02d} {hh:02d}:{mm:02d}"
        return f"{y:04d}-{m:02d}-{d:02d}"

    raise ValueError(f"Invalid due date format: {raw_due}")


def parse_stored_due(due_str):
    """Parse canonical due_str into (datetime, has_time)."""
    due_clean = due_str.replace("T", " ").strip()
    if len(due_clean) == 10:
        dt = datetime.strptime(due_clean, "%Y-%m-%d").replace(hour=23, minute=59)
        return dt, False
    if len(due_clean) == 16:
        dt = datetime.strptime(due_clean, "%Y-%m-%d %H:%M")
        return dt, True
    dt = datetime.strptime(due_clean[:19], "%Y-%m-%d %H:%M:%S")
    return dt, True


def compute_next_recurrence_due(due_str, recurrence):
    """Compute the next occurrence due string for daily/weekly/monthly recurring tasks."""
    now = datetime.now()
    if due_str:
        try:
            dt, has_time = parse_stored_due(due_str)
        except Exception:
            dt, has_time = now, True
    else:
        dt, has_time = now, False

    if recurrence == "daily":
        next_dt = dt + timedelta(days=1)
    elif recurrence == "weekly":
        next_dt = dt + timedelta(days=7)
    elif recurrence == "monthly":
        year = dt.year
        month = dt.month + 1
        if month > 12:
            month = 1
            year += 1
        max_day = calendar.monthrange(year, month)[1]
        next_dt = dt.replace(year=year, month=month, day=min(dt.day, max_day))
    else:
        return due_str

    if has_time:
        return next_dt.strftime("%Y-%m-%d %H:%M")
    return next_dt.strftime("%Y-%m-%d")


def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA busy_timeout = 5000")
    return conn


def init_db():
    with get_db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                due_date TEXT DEFAULT '',
                priority INTEGER DEFAULT 3,
                tag TEXT DEFAULT '',
                estimate TEXT DEFAULT '',
                notes TEXT DEFAULT '',
                recurrence TEXT DEFAULT '',
                sort_order INTEGER DEFAULT 0,
                completed INTEGER DEFAULT 0,
                completed_at TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                notified_flags TEXT DEFAULT ''
            )
            """
        )
        # Safe non-destructive schema migrations for existing DBs
        existing_cols = {
            row["name"] for row in conn.execute("PRAGMA table_info(tasks)").fetchall()
        }
        if "notes" not in existing_cols:
            conn.execute("ALTER TABLE tasks ADD COLUMN notes TEXT DEFAULT ''")
        if "recurrence" not in existing_cols:
            conn.execute("ALTER TABLE tasks ADD COLUMN recurrence TEXT DEFAULT ''")
        if "sort_order" not in existing_cols:
            conn.execute("ALTER TABLE tasks ADD COLUMN sort_order INTEGER DEFAULT 0")

        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS subtasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                completed INTEGER DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """
        )

        default_settings = {
            "notifications_enabled": "true",
            "notify_60m": "true",
            "notify_15m": "true",
            "notify_due": "true",
            "interactive_notifications": "true",
            "default_priority": "3",
            "calendar_mode": "jalali",
        }
        for k, v in default_settings.items():
            conn.execute(
                "INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)", (k, v)
            )

        conn.commit()


def get_settings():
    with get_db() as conn:
        rows = conn.execute("SELECT key, value FROM settings").fetchall()
        return {r["key"]: r["value"] for r in rows}


def format_human_due(due_str):
    if not due_str:
        return {
            "due_human": "No deadline",
            "due_short": "",
            "due_rel": "",
            "due_jalali": "",
            "due_jalali_date": "",
            "due_gregorian": "",
            "due_time": "",
            "due_iso_date": "",
            "is_overdue": False,
            "diff_mins": 9999999,
        }

    try:
        due_dt, has_time = parse_stored_due(due_str)
        now = datetime.now()
        diff = due_dt - now
        total_seconds = int(diff.total_seconds())
        diff_mins = total_seconds // 60

        is_overdue = total_seconds < 0
        abs_seconds = abs(total_seconds)
        abs_mins = abs_seconds // 60
        abs_hours = abs_mins // 60
        abs_days = abs_hours // 24

        if is_overdue:
            if abs_mins < 60:
                rel = f"Overdue {abs_mins}m"
            elif abs_hours < 24:
                rel = f"Overdue {abs_hours}h {abs_mins % 60}m"
            else:
                rel = f"Overdue {abs_days}d"
        else:
            if abs_mins < 60:
                rel = f"in {abs_mins}m"
            elif abs_hours < 24:
                rel = f"in {abs_hours}h {abs_mins % 60}m"
            else:
                rel = f"in {abs_days}d"

        time_only = due_dt.strftime("%H:%M") if has_time else ""
        time_part = f" {time_only}" if has_time else ""

        if due_dt.date() == now.date():
            short = f"Today{time_part}"
        elif due_dt.date() == (now + timedelta(days=1)).date():
            short = f"Tomorrow{time_part}"
        else:
            short = f"{due_dt.strftime('%b %d')}{time_part}"

        human = f"{short} ({rel})"

        jy, jm, jd = g2j(due_dt.year, due_dt.month, due_dt.day)
        j_month_name = FA_MONTHS[jm]
        j_day_name = FA_WEEKDAYS.get(due_dt.weekday(), "")
        jalali_date = f"{j_day_name} {jd} {j_month_name} {jy}".strip()
        jalali_str = f"{jalali_date}{time_part}".strip()
        gregorian_str = f"{due_dt.strftime('%a, %d %b %Y')}{time_part}".strip()

        return {
            "due_human": human,
            "due_short": short,
            "due_rel": rel,
            "due_jalali": jalali_str,
            "due_jalali_date": jalali_date,
            "due_gregorian": gregorian_str,
            "due_time": time_only,
            "due_iso_date": due_dt.strftime("%Y-%m-%d"),
            "is_overdue": is_overdue,
            "diff_mins": diff_mins,
        }
    except Exception:
        return {
            "due_human": due_str,
            "due_short": due_str,
            "due_rel": "",
            "due_jalali": due_str,
            "due_jalali_date": due_str,
            "due_gregorian": due_str,
            "due_time": "",
            "due_iso_date": "",
            "is_overdue": False,
            "diff_mins": 9999999,
        }


def toggle_task_db(task_id):
    with get_db() as conn:
        task = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        if not task:
            return None
        new_state = 0 if task["completed"] == 1 else 1
        completed_at = datetime.now().isoformat() if new_state == 1 else None
        conn.execute(
            "UPDATE tasks SET completed = ?, completed_at = ? WHERE id = ?",
            (new_state, completed_at, task_id),
        )

        next_id = None
        recurrence = (task["recurrence"] or "").strip()
        if new_state == 1 and recurrence in ("daily", "weekly", "monthly"):
            next_due = compute_next_recurrence_due(task["due_date"] or "", recurrence)
            cur = conn.execute(
                """
                INSERT INTO tasks (title, due_date, priority, tag, estimate, notes, recurrence)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    task["title"],
                    next_due,
                    task["priority"],
                    task["tag"] or "",
                    task["estimate"] or "",
                    task["notes"] or "",
                    recurrence,
                ),
            )
            next_id = cur.lastrowid
            subs = conn.execute(
                "SELECT title FROM subtasks WHERE task_id = ? ORDER BY id ASC",
                (task_id,),
            ).fetchall()
            for s in subs:
                conn.execute(
                    "INSERT INTO subtasks (task_id, title) VALUES (?, ?)",
                    (next_id, s["title"]),
                )

        conn.commit()
        return {"completed": new_state, "next_id": next_id}


def snooze_task_db(task_id, minutes):
    with get_db() as conn:
        task = conn.execute(
            "SELECT due_date FROM tasks WHERE id = ?", (task_id,)
        ).fetchone()
        if not task:
            return None
        now = datetime.now()
        base_dt = now
        if task["due_date"]:
            try:
                parsed_dt, _ = parse_stored_due(task["due_date"])
                if parsed_dt > now:
                    base_dt = parsed_dt
            except Exception:
                pass
        new_dt = base_dt + timedelta(minutes=minutes)
        new_due = new_dt.strftime("%Y-%m-%d %H:%M")
        conn.execute(
            "UPDATE tasks SET due_date = ?, notified_flags = '', completed = 0, completed_at = NULL WHERE id = ?",
            (new_due, task_id),
        )
        conn.commit()
        return new_due


def _dispatch_notification_async(task_id, flag, title, body, urgency, interactive):
    key = (task_id, flag)
    with NOTIF_LOCK:
        if key in ACTIVE_NOTIF_THREADS:
            return
        ACTIVE_NOTIF_THREADS.add(key)

    def _run():
        try:
            cmd = [
                "notify-send",
                "-a", "TaskFlow",
                "-u", urgency,
                "-i", "appointment-soon",
            ]
            if interactive:
                cmd.extend(["-A", "done=Mark Done", "-A", "snooze15=Snooze 15m"])
            cmd.extend([title, body])

            timeout = 120 if interactive else 5
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            action = (proc.stdout or "").strip()
            if interactive and action == "done":
                toggle_task_db(task_id)
            elif interactive and action == "snooze15":
                snooze_task_db(task_id, 15)
        except subprocess.TimeoutExpired:
            pass
        except Exception as e:
            print(f"Error sending notification: {e}", file=sys.stderr)
        finally:
            with NOTIF_LOCK:
                ACTIVE_NOTIF_THREADS.discard(key)

    threading.Thread(target=_run, daemon=True).start()


def notification_worker():
    while True:
        try:
            settings = get_settings()
            if settings.get("notifications_enabled", "true") == "true":
                interactive = settings.get("interactive_notifications", "true") == "true"
                now = datetime.now()
                with get_db() as conn:
                    tasks = conn.execute(
                        "SELECT id, title, due_date, priority, tag, notified_flags FROM tasks WHERE completed = 0 AND due_date != ''"
                    ).fetchall()

                    for t in tasks:
                        t_id = t["id"]
                        t_title = t["title"]
                        due_str = t["due_date"]
                        flags = set(
                            f for f in (t["notified_flags"] or "").split(",") if f
                        )

                        try:
                            due_dt, _ = parse_stored_due(due_str)
                            diff_mins = (due_dt - now).total_seconds() / 60.0
                            tag_str = f" [{t['tag']}]" if t["tag"] else ""

                            if settings.get("notify_60m", "true") == "true":
                                if 15 < diff_mins <= 60 and "60m" not in flags:
                                    _dispatch_notification_async(
                                        t_id,
                                        "60m",
                                        f"Task Due Soon{tag_str}",
                                        f"{t_title}\nDue in ~{int(diff_mins)}m ({due_dt.strftime('%H:%M')})",
                                        "normal",
                                        interactive,
                                    )
                                    flags.add("60m")

                            if settings.get("notify_15m", "true") == "true":
                                if 0 < diff_mins <= 15 and "15m" not in flags:
                                    _dispatch_notification_async(
                                        t_id,
                                        "15m",
                                        f"Urgent: Due in {max(1, int(diff_mins))}m{tag_str}",
                                        f"{t_title}\nDue at {due_dt.strftime('%H:%M')}",
                                        "critical",
                                        interactive,
                                    )
                                    flags.add("15m")

                            if settings.get("notify_due", "true") == "true":
                                if diff_mins <= 0 and "due" not in flags:
                                    _dispatch_notification_async(
                                        t_id,
                                        "due",
                                        f"Task Overdue{tag_str}",
                                        f"{t_title} is now overdue!",
                                        "critical",
                                        interactive,
                                    )
                                    flags.add("due")

                            new_flags_str = ",".join(sorted(flags))
                            if new_flags_str != (t["notified_flags"] or ""):
                                conn.execute(
                                    "UPDATE tasks SET notified_flags = ? WHERE id = ?",
                                    (new_flags_str, t_id),
                                )
                        except Exception:
                            pass
                    conn.commit()
        except Exception as e:
            print(f"Notification loop error: {e}", file=sys.stderr)

        time.sleep(30)


def serialize_task(conn, t):
    t_id = t["id"]
    subtasks = conn.execute(
        "SELECT id, title, completed FROM subtasks WHERE task_id = ? ORDER BY id ASC",
        (t_id,),
    ).fetchall()
    sub_list = [dict(s) for s in subtasks]
    due_info = format_human_due(t["due_date"])
    prio = t["priority"]
    p_meta = PRIORITY_MAP.get(prio, PRIORITY_MAP[3])

    return {
        "id": t_id,
        "title": t["title"],
        "due_date": t["due_date"] or "",
        "due_human": due_info["due_human"],
        "due_short": due_info["due_short"],
        "due_rel": due_info["due_rel"],
        "due_jalali": due_info["due_jalali"],
        "due_jalali_date": due_info["due_jalali_date"],
        "due_gregorian": due_info["due_gregorian"],
        "due_time": due_info["due_time"],
        "due_iso_date": due_info["due_iso_date"],
        "is_overdue": due_info["is_overdue"],
        "diff_mins": due_info["diff_mins"],
        "priority": prio,
        "priority_name": p_meta["name"],
        "priority_color": p_meta["color"],
        "tag": t["tag"] or "",
        "estimate": t["estimate"] or "",
        "notes": t["notes"] or "",
        "recurrence": t["recurrence"] or "",
        "completed": t["completed"],
        "completed_at": t["completed_at"] or "",
        "created_at": t["created_at"],
        "subtasks": sub_list,
        "subtasks_count": len(sub_list),
        "subtasks_done": sum(1 for s in sub_list if s["completed"] == 1),
    }


class TaskHandler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def log_message(self, format, *args):
        return

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/stats":
            with get_db() as conn:
                tasks = conn.execute(
                    """
                    SELECT id, title, due_date, priority, tag, estimate, completed, sort_order
                    FROM tasks
                    ORDER BY completed ASC, sort_order ASC, priority ASC,
                             CASE WHEN due_date='' THEN 1 ELSE 0 END, due_date ASC, id DESC
                    """
                ).fetchall()
                total_pending = sum(1 for t in tasks if t["completed"] == 0)
                total_completed = sum(1 for t in tasks if t["completed"] == 1)

                overdue_count = 0
                today_count = 0
                urgent_count = 0
                upcoming_tasks = []
                active_pill_tasks = []
                tag_counts = {}
                all_tag_counts = {}

                for t in tasks:
                    tag = (t["tag"] or "").strip()
                    if tag:
                        all_tag_counts[tag] = all_tag_counts.get(tag, 0) + 1
                    if t["completed"] == 0:
                        if t["priority"] == 1:
                            urgent_count += 1
                        if tag:
                            tag_counts[tag] = tag_counts.get(tag, 0) + 1
                        d = format_human_due(t["due_date"]) if t["due_date"] else None
                        if d:
                            if d["is_overdue"]:
                                overdue_count += 1
                            if d["diff_mins"] <= 1440 and not d["is_overdue"]:
                                today_count += 1
                            upcoming_tasks.append(
                                {
                                    "id": t["id"],
                                    "title": t["title"],
                                    "priority": t["priority"],
                                    "priority_name": PRIORITY_MAP.get(t["priority"], PRIORITY_MAP[3])["name"],
                                    "tag": tag,
                                    "estimate": t["estimate"] or "",
                                    "due_human": d["due_human"],
                                    "due_short": d["due_short"],
                                    "due_rel": d["due_rel"],
                                    "due_jalali": d["due_jalali"],
                                    "due_jalali_date": d["due_jalali_date"],
                                    "due_time": d["due_time"],
                                    "due_gregorian": d["due_gregorian"],
                                    "is_overdue": d["is_overdue"],
                                    "diff_mins": d["diff_mins"],
                                }
                            )
                        if len(active_pill_tasks) < 8:
                            active_pill_tasks.append(
                                {
                                    "id": t["id"],
                                    "title": t["title"],
                                    "priority": t["priority"],
                                    "priority_name": PRIORITY_MAP.get(t["priority"], PRIORITY_MAP[3])["name"],
                                    "tag": tag,
                                    "estimate": t["estimate"] or "",
                                    "due_short": d["due_short"] if d else "",
                                    "due_rel": d["due_rel"] if d else "",
                                    "due_jalali_date": d["due_jalali_date"] if d else "",
                                    "due_time": d["due_time"] if d else "",
                                    "is_overdue": d["is_overdue"] if d else False,
                                    "diff_mins": d["diff_mins"] if d else 9999999,
                                }
                            )

                upcoming_tasks.sort(key=lambda x: x["diff_mins"])
                next_task = upcoming_tasks[0] if upcoming_tasks else None
                focus_task = (
                    upcoming_tasks[0]
                    if upcoming_tasks and (upcoming_tasks[0]["is_overdue"] or upcoming_tasks[0]["diff_mins"] <= 1440)
                    else (active_pill_tasks[0] if active_pill_tasks else None)
                )
                tags_list = [
                    {"name": k, "count": v}
                    for k, v in sorted(tag_counts.items(), key=lambda kv: (-kv[1], kv[0]))
                ]
                all_tags_list = [
                    k
                    for k, _ in sorted(all_tag_counts.items(), key=lambda kv: (-kv[1], kv[0]))
                ]

                self._send_json(
                    200,
                    {
                        "daemon_ok": True,
                        "pending_count": total_pending,
                        "completed_count": total_completed,
                        "overdue_count": overdue_count,
                        "today_count": today_count,
                        "urgent_count": urgent_count,
                        "next_task": next_task,
                        "focus_task": focus_task,
                        "active_pill_tasks": active_pill_tasks,
                        "top_upcoming": upcoming_tasks[:3],
                        "tags": tags_list,
                        "all_tags": all_tags_list,
                    },
                )
            return

        if path == "/settings":
            self._send_json(200, get_settings())
            return

        if path == "/calendar/month":
            now = datetime.now()
            today_jy, today_jm, today_jd = g2j(now.year, now.month, now.day)
            with get_db() as conn:
                tasks = conn.execute(
                    "SELECT * FROM tasks WHERE due_date != '' ORDER BY completed ASC, priority ASC, due_date ASC"
                ).fetchall()
                serialized = [serialize_task(conn, t) for t in tasks]
            self._send_json(
                200,
                {
                    "today_jalali": {"year": today_jy, "month": today_jm, "day": today_jd},
                    "today_gregorian": {"year": now.year, "month": now.month, "day": now.day},
                    "tasks": serialized,
                    "tasks_count": sum(1 for t in serialized if t["completed"] == 0),
                },
            )
            return

        if path == "/tasks":
            filter_mode = query.get("filter", ["all"])[0]
            tag_filter = query.get("tag", [""])[0].strip()
            sort_mode = query.get("sort", ["priority"])[0]

            with get_db() as conn:
                sql = "SELECT * FROM tasks"
                clauses = []
                params = []
                if filter_mode == "active":
                    clauses.append("completed = 0")
                elif filter_mode == "completed":
                    clauses.append("completed = 1")
                if tag_filter:
                    clauses.append("LOWER(tag) = LOWER(?)")
                    params.append(tag_filter)
                if clauses:
                    sql += " WHERE " + " AND ".join(clauses)

                if sort_mode == "due":
                    sql += " ORDER BY completed ASC, CASE WHEN due_date='' THEN 1 ELSE 0 END, due_date ASC, priority ASC, sort_order ASC, id DESC"
                elif sort_mode == "created":
                    sql += " ORDER BY completed ASC, id DESC"
                else:
                    sql += " ORDER BY completed ASC, sort_order ASC, priority ASC, CASE WHEN due_date='' THEN 1 ELSE 0 END, due_date ASC, id DESC"

                tasks = conn.execute(sql, params).fetchall()
                result = []
                for t in tasks:
                    td = serialize_task(conn, t)
                    if filter_mode == "today":
                        if t["completed"] == 0 and (td["is_overdue"] or td["diff_mins"] <= 1440):
                            result.append(td)
                    elif filter_mode == "upcoming":
                        if t["completed"] == 0 and not td["is_overdue"]:
                            result.append(td)
                    else:
                        result.append(td)

                self._send_json(200, result)
            return

        self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", 0))
        data = {}
        if length > 0:
            try:
                body = self.rfile.read(length).decode("utf-8")
                data = json.loads(body)
            except Exception:
                self._send_json(400, {"error": "Invalid JSON"})
                return

        if path == "/settings":
            with get_db() as conn:
                for k, v in data.items():
                    conn.execute(
                        "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                        (k, str(v)),
                    )
                conn.commit()
            self._send_json(200, {"success": True})
            return

        if path == "/tasks/clear-completed":
            with get_db() as conn:
                cur = conn.execute("DELETE FROM tasks WHERE completed = 1")
                deleted = cur.rowcount
                conn.commit()
            self._send_json(200, {"success": True, "deleted": deleted})
            return

        if path == "/tasks":
            title = (data.get("title") or "").strip()
            if not title:
                self._send_json(400, {"error": "Title is required"})
                return

            try:
                due_date = parse_due_input(data.get("due_date", ""))
            except ValueError as e:
                self._send_json(400, {"error": str(e)})
                return

            priority = max(1, min(4, int(data.get("priority", 3))))
            tag = (data.get("tag") or "").strip()
            estimate = (data.get("estimate") or "").strip()
            notes = (data.get("notes") or "").strip()
            recurrence = (data.get("recurrence") or "").strip().lower()
            if recurrence not in ("", "daily", "weekly", "monthly"):
                recurrence = ""
            subtasks = data.get("subtasks", [])

            with get_db() as conn:
                cur = conn.execute(
                    """
                    INSERT INTO tasks (title, due_date, priority, tag, estimate, notes, recurrence)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (title, due_date, priority, tag, estimate, notes, recurrence),
                )
                task_id = cur.lastrowid
                for s in subtasks:
                    if isinstance(s, str) and s.strip():
                        conn.execute(
                            "INSERT INTO subtasks (task_id, title) VALUES (?, ?)",
                            (task_id, s.strip()),
                        )
                    elif isinstance(s, dict) and (s.get("title") or "").strip():
                        conn.execute(
                            "INSERT INTO subtasks (task_id, title) VALUES (?, ?)",
                            (task_id, s["title"].strip()),
                        )
                conn.commit()

            self._send_json(201, {"success": True, "id": task_id, "due_date": due_date})
            return

        if path == "/tasks/update":
            task_id = data.get("id")
            if not task_id:
                self._send_json(400, {"error": "Task id is required"})
                return

            with get_db() as conn:
                existing = conn.execute(
                    "SELECT * FROM tasks WHERE id = ?", (task_id,)
                ).fetchone()
                if not existing:
                    self._send_json(404, {"error": "Task not found"})
                    return

                title = (
                    data["title"].strip()
                    if "title" in data and data["title"] is not None
                    else existing["title"]
                )
                if not title:
                    self._send_json(400, {"error": "Title cannot be empty"})
                    return

                new_due = existing["due_date"] or ""
                notified_flags = existing["notified_flags"] or ""
                if "due_date" in data:
                    try:
                        new_due = parse_due_input(data["due_date"])
                    except ValueError as e:
                        self._send_json(400, {"error": str(e)})
                        return
                    if new_due != (existing["due_date"] or ""):
                        notified_flags = ""

                priority = (
                    max(1, min(4, int(data["priority"])))
                    if "priority" in data and data["priority"] is not None
                    else existing["priority"]
                )
                tag = (
                    (data["tag"] or "").strip()
                    if "tag" in data
                    else (existing["tag"] or "")
                )
                estimate = (
                    (data["estimate"] or "").strip()
                    if "estimate" in data
                    else (existing["estimate"] or "")
                )
                notes = (
                    (data["notes"] or "").strip()
                    if "notes" in data
                    else (existing["notes"] or "")
                )
                recurrence = (
                    (data["recurrence"] or "").strip().lower()
                    if "recurrence" in data
                    else (existing["recurrence"] or "")
                )
                if recurrence not in ("", "daily", "weekly", "monthly"):
                    recurrence = ""

                conn.execute(
                    """
                    UPDATE tasks
                    SET title = ?, due_date = ?, priority = ?, tag = ?, estimate = ?,
                        notes = ?, recurrence = ?, notified_flags = ?
                    WHERE id = ?
                    """,
                    (
                        title,
                        new_due,
                        priority,
                        tag,
                        estimate,
                        notes,
                        recurrence,
                        notified_flags,
                        task_id,
                    ),
                )
                conn.commit()

            self._send_json(200, {"success": True, "id": task_id, "due_date": new_due})
            return

        if path == "/tasks/snooze":
            task_id = data.get("id")
            if not task_id:
                self._send_json(400, {"error": "Task id is required"})
                return
            preset = (data.get("preset") or "").strip().lower()
            if preset == "1h":
                minutes = 60
            elif preset == "3h":
                minutes = 180
            elif preset == "tomorrow":
                minutes = 1440
            else:
                minutes = int(data.get("minutes", 60))

            new_due = snooze_task_db(task_id, minutes)
            if new_due is None:
                self._send_json(404, {"error": "Task not found"})
                return
            self._send_json(200, {"success": True, "due_date": new_due})
            return

        if path == "/tasks/toggle":
            task_id = data.get("id")
            if not task_id:
                self._send_json(400, {"error": "Task id is required"})
                return
            res = toggle_task_db(task_id)
            if res is None:
                self._send_json(404, {"error": "Task not found"})
                return
            self._send_json(
                200,
                {
                    "success": True,
                    "completed": res["completed"],
                    "next_id": res["next_id"],
                },
            )
            return

        if path == "/tasks/reorder":
            raw_ids = data.get("ordered_ids")
            if not isinstance(raw_ids, list) or not raw_ids:
                self._send_json(400, {"error": "ordered_ids must be a non-empty list"})
                return
            try:
                ordered_ids = [int(x) for x in raw_ids]
            except (TypeError, ValueError):
                self._send_json(400, {"error": "Invalid task id in ordered_ids"})
                return

            with get_db() as conn:
                global_rows = conn.execute(
                    """
                    SELECT id FROM tasks
                    WHERE completed = 0
                    ORDER BY sort_order ASC, priority ASC,
                             CASE WHEN due_date='' THEN 1 ELSE 0 END, due_date ASC, id DESC
                    """
                ).fetchall()
                global_ids = [r["id"] for r in global_rows]
                subset_set = set(ordered_ids)
                # Keep relative positions of non-visible tasks; place ordered_ids in their slots
                filtered_ordered = [tid for tid in ordered_ids if tid in global_ids]
                it = iter(filtered_ordered)
                merged_ids = [next(it) if gid in subset_set else gid for gid in global_ids]

                for idx, tid in enumerate(merged_ids):
                    conn.execute(
                        "UPDATE tasks SET sort_order = ? WHERE id = ?",
                        ((idx + 1) * 10, tid),
                    )
                conn.commit()
            self._send_json(200, {"success": True})
            return

        if path == "/tasks/delete":
            task_id = data.get("id")
            if not task_id:
                self._send_json(400, {"error": "Task id is required"})
                return
            with get_db() as conn:
                conn.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
                conn.commit()
            self._send_json(200, {"success": True})
            return

        if path == "/subtasks/toggle":
            subtask_id = data.get("id")
            if not subtask_id:
                self._send_json(400, {"error": "Subtask id is required"})
                return
            with get_db() as conn:
                sub = conn.execute(
                    "SELECT completed FROM subtasks WHERE id = ?", (subtask_id,)
                ).fetchone()
                if not sub:
                    self._send_json(404, {"error": "Subtask not found"})
                    return
                new_state = 0 if sub["completed"] == 1 else 1
                conn.execute(
                    "UPDATE subtasks SET completed = ? WHERE id = ?",
                    (new_state, subtask_id),
                )
                conn.commit()
            self._send_json(200, {"success": True, "completed": new_state})
            return

        if path == "/subtasks/add":
            task_id = data.get("task_id")
            title = (data.get("title") or "").strip()
            if not task_id or not title:
                self._send_json(400, {"error": "task_id and title are required"})
                return
            with get_db() as conn:
                cur = conn.execute(
                    "INSERT INTO subtasks (task_id, title) VALUES (?, ?)",
                    (task_id, title),
                )
                sub_id = cur.lastrowid
                conn.commit()
            self._send_json(201, {"success": True, "id": sub_id})
            return

        if path == "/subtasks/delete":
            subtask_id = data.get("id")
            if not subtask_id:
                self._send_json(400, {"error": "Subtask id is required"})
                return
            with get_db() as conn:
                conn.execute("DELETE FROM subtasks WHERE id = ?", (subtask_id,))
                conn.commit()
            self._send_json(200, {"success": True})
            return

        self._send_json(404, {"error": "Endpoint not found"})


def run_server():
    init_db()

    notif_thread = threading.Thread(target=notification_worker, daemon=True)
    notif_thread.start()

    ThreadingHTTPServer.allow_reuse_address = True
    server = ThreadingHTTPServer(("127.0.0.1", PORT), TaskHandler)
    print(f"TaskFlow daemon listening on 127.0.0.1:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    run_server()
