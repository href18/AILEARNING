"""Database layer for compliance training platform using SQLite."""
from __future__ import annotations

import json
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, Tuple

DB_PATH = Path(__file__).resolve().parent.parent / "data" / "app.db"
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

_lock = threading.RLock()


def _dict_factory(cursor: sqlite3.Cursor, row: Tuple[Any, ...]) -> Dict[str, Any]:
    return {col[0]: row[idx] for idx, col in enumerate(cursor.description)}


@contextmanager
def get_conn(readonly: bool = False) -> Iterable[sqlite3.Connection]:
    with _lock:
        uri = f"file:{DB_PATH}?mode={'ro' if readonly else 'rw'}"
        if not DB_PATH.exists() and not readonly:
            uri = f"file:{DB_PATH}?mode=rwc"
        conn = sqlite3.connect(uri, uri=True, timeout=30)
        conn.row_factory = _dict_factory
        try:
            yield conn
            if not readonly:
                conn.commit()
        finally:
            conn.close()


def init_db() -> None:
    """Initialise the SQLite database with required tables."""
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            """
            PRAGMA foreign_keys = ON;
            """
        )
        cur.executescript(
            """
            create table if not exists users (
                id text primary key,
                email text unique not null,
                password_hash text not null,
                name text,
                locale text default 'nb',
                created_at text not null,
                updated_at text not null
            );

            create table if not exists orgs (
                id text primary key,
                name text not null,
                billing_plan text default 'per_seat',
                created_at text not null
            );

            create table if not exists org_members (
                org_id text not null references orgs(id) on delete cascade,
                user_id text not null references users(id) on delete cascade,
                role text not null check(role in ('participant','admin','author','super_admin')),
                primary key (org_id, user_id)
            );

            create table if not exists courses (
                id text primary key,
                code text unique,
                status text check(status in ('draft','published')) default 'draft',
                duration_minutes integer,
                certificate_valid_months integer default 12,
                created_by text references users(id),
                created_at text not null,
                updated_at text not null
            );

            create table if not exists course_i18n (
                course_id text references courses(id) on delete cascade,
                locale text not null,
                title text,
                summary text,
                primary key (course_id, locale)
            );

            create table if not exists modules (
                id text primary key,
                course_id text references courses(id) on delete cascade,
                type text check(type in ('video','article','quiz','simulation')),
                position integer,
                passing_score integer,
                shuffle integer default 1
            );

            create table if not exists module_i18n (
                module_id text references modules(id) on delete cascade,
                locale text not null,
                title text,
                body_md text,
                video_url text,
                primary key (module_id, locale)
            );

            create table if not exists quiz_questions (
                id text primary key,
                module_id text references modules(id) on delete cascade,
                body text not null,
                type text check(type in ('single','multi')),
                explanation text
            );

            create table if not exists quiz_options (
                id text primary key,
                question_id text references quiz_questions(id) on delete cascade,
                body text,
                is_correct integer default 0
            );

            create table if not exists assignments (
                id text primary key,
                org_id text references orgs(id) on delete cascade,
                course_id text references courses(id),
                assigned_by text references users(id),
                assigned_to text references users(id),
                due_at text,
                created_at text not null
            );

            create table if not exists progress (
                id text primary key,
                assignment_id text references assignments(id) on delete cascade,
                module_id text references modules(id),
                completed_at text,
                last_pos integer,
                score integer,
                attempts integer default 0,
                updated_at text not null
            );

            create table if not exists certificates (
                id text primary key,
                assignment_id text references assignments(id) on delete cascade,
                issued_at text not null,
                expires_at text,
                pdf_url text
            );

            create table if not exists audit_logs (
                id integer primary key autoincrement,
                org_id text,
                actor text,
                action text,
                subject text,
                meta text,
                created_at text not null
            );
            """
        )


def now_ts() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def add_audit(org_id: str, actor: str, action: str, subject: str, meta: Dict[str, Any]) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            insert into audit_logs (org_id, actor, action, subject, meta, created_at)
            values (?, ?, ?, ?, ?, ?)
            """,
            (org_id, actor, action, subject, json.dumps(meta or {}), now_ts()),
        )


def calculate_expiry(issued_at: datetime, months: int) -> datetime:
    month = issued_at.month - 1 + months
    year = issued_at.year + month // 12
    month = month % 12 + 1
    day = min(issued_at.day, [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1])
    return issued_at.replace(year=year, month=month, day=day)


def ensure_indexes() -> None:
    with get_conn() as conn:
        conn.executescript(
            """
            create index if not exists idx_assignments_org on assignments(org_id);
            create index if not exists idx_assignments_user on assignments(assigned_to);
            create index if not exists idx_progress_assignment on progress(assignment_id);
            create index if not exists idx_certificates_assignment on certificates(assignment_id);
            create index if not exists idx_audit_org on audit_logs(org_id);
            """
        )


init_db()
ensure_indexes()
