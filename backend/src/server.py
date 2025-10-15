"""HTTP server implementing the compliance training MVP backend."""
from __future__ import annotations

import json
import urllib.parse
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, Dict, List, Tuple
from uuid import uuid4

from . import db
from .auth import AuthError, hash_password, sign_token, verify_password, verify_token


def json_response(handler: BaseHTTPRequestHandler, status: int, payload: Any) -> None:
    data = json.dumps(payload).encode()
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def parse_body(handler: BaseHTTPRequestHandler) -> Dict[str, Any]:
    length = int(handler.headers.get("Content-Length", "0"))
    if length == 0:
        return {}
    data = handler.rfile.read(length)
    if not data:
        return {}
    try:
        return json.loads(data.decode())
    except json.JSONDecodeError:
        raise ValueError("Invalid JSON payload")


def require_auth(handler: BaseHTTPRequestHandler) -> Tuple[str, str, str]:
    header = handler.headers.get("Authorization")
    if not header or not header.startswith("Bearer "):
        raise AuthError("Missing bearer token")
    token = header.split(" ", 1)[1]
    parsed = verify_token(token)
    return parsed.user_id, parsed.org_id, parsed.role


def build_status(row: Dict[str, Any]) -> str:
    if row.get("certificate_id"):
        return "completed"
    due_at = row.get("due_at")
    if due_at:
        due = datetime.fromisoformat(due_at.rstrip("Z"))
        if due < datetime.utcnow():
            return "overdue"
    if row.get("progress_count", 0) > 0:
        return "in_progress"
    return "assigned"


class TrainingRequestHandler(BaseHTTPRequestHandler):
    server_version = "TrainingServer/0.1"

    def do_OPTIONS(self) -> None:  # pragma: no cover - CORS helper
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
        self.end_headers()

    def do_POST(self) -> None:  # noqa: N802 - required name
        try:
            if self.path == "/auth/register":
                self.handle_register()
            elif self.path == "/auth/login":
                self.handle_login()
            elif self.path == "/courses":
                self.handle_create_course()
            elif self.path == "/assignments":
                self.handle_assignments()
            elif self.path == "/progress":
                self.handle_progress()
            elif self.path == "/quiz/submit":
                self.handle_quiz_submit()
            elif self.path == "/certificates/issue":
                self.handle_issue_certificate()
            elif self.path == "/setup/demo":
                self.handle_demo_setup()
            else:
                self.send_error(HTTPStatus.NOT_FOUND, "Unknown endpoint")
        except AuthError as exc:
            json_response(self, HTTPStatus.UNAUTHORIZED, {"error": str(exc)})
        except ValueError as exc:
            json_response(self, HTTPStatus.BAD_REQUEST, {"error": str(exc)})
        except Exception as exc:  # pragma: no cover - safety net
            json_response(self, HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})

    def do_GET(self) -> None:  # noqa: N802
        try:
            if self.path.startswith("/assignments"):
                self.handle_list_assignments()
            elif self.path.startswith("/courses"):
                self.handle_list_courses()
            elif self.path.startswith("/reports/completions.csv"):
                self.handle_report()
            else:
                self.send_error(HTTPStatus.NOT_FOUND, "Unknown endpoint")
        except AuthError as exc:
            json_response(self, HTTPStatus.UNAUTHORIZED, {"error": str(exc)})
        except ValueError as exc:
            json_response(self, HTTPStatus.BAD_REQUEST, {"error": str(exc)})
        except Exception as exc:  # pragma: no cover
            json_response(self, HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})

    def handle_register(self) -> None:
        payload = parse_body(self)
        required = ["email", "password", "name"]
        if not all(payload.get(field) for field in required):
            raise ValueError("Missing registration fields")
        email = payload["email"].lower()
        user_id = str(uuid4())
        org_id = payload.get("org_id")
        org_role = payload.get("role", "participant")
        created_at = db.now_ts()
        password_hash = hash_password(payload["password"])
        with db.get_conn() as conn:
            conn.execute(
                """
                insert into users(id, email, password_hash, name, created_at, updated_at)
                values (?, ?, ?, ?, ?, ?)
                """,
                (user_id, email, password_hash, payload["name"], created_at, created_at),
            )
            if payload.get("org_name"):
                org_id = org_id or str(uuid4())
                conn.execute(
                    """
                    insert into orgs(id, name, billing_plan, created_at)
                    values (?, ?, ?, ?)
                    """,
                    (org_id, payload["org_name"], payload.get("billing_plan", "per_seat"), created_at),
                )
                org_role = "admin"
            if org_id:
                conn.execute(
                    """
                    insert or replace into org_members(org_id, user_id, role)
                    values (?, ?, ?)
                    """,
                    (org_id, user_id, org_role),
                )
        token = sign_token(user_id, org_id or "", org_role)
        json_response(
            self,
            HTTPStatus.CREATED,
            {"user_id": user_id, "org_id": org_id, "role": org_role, "token": token},
        )

    def handle_login(self) -> None:
        payload = parse_body(self)
        email = payload.get("email", "").lower()
        org_id = payload.get("org_id")
        if not email or not payload.get("password"):
            raise ValueError("Missing login fields")
        with db.get_conn(readonly=True) as conn:
            row = conn.execute("select * from users where email = ?", (email,)).fetchone()
            if not row or not verify_password(payload["password"], row["password_hash"]):
                raise AuthError("Invalid credentials")
            if not org_id:
                membership = conn.execute(
                    "select org_id, role from org_members where user_id = ? limit 1",
                    (row["id"],),
                ).fetchone()
            else:
                membership = conn.execute(
                    "select org_id, role from org_members where user_id = ? and org_id = ?",
                    (row["id"], org_id),
                ).fetchone()
        if not membership:
            raise AuthError("User is not part of an organisation")
        token = sign_token(row["id"], membership["org_id"], membership["role"])
        json_response(
            self,
            HTTPStatus.OK,
            {
                "user_id": row["id"],
                "org_id": membership["org_id"],
                "role": membership["role"],
                "token": token,
            },
        )

    def handle_create_course(self) -> None:
        user_id, org_id, role = require_auth(self)
        if role not in {"admin", "author", "super_admin"}:
            raise AuthError("Only authors or admins can create courses")
        payload = parse_body(self)
        course_id = str(uuid4())
        created_at = db.now_ts()
        with db.get_conn() as conn:
            conn.execute(
                """
                insert into courses(id, code, status, duration_minutes, certificate_valid_months, created_by, created_at, updated_at)
                values (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    course_id,
                    payload.get("code"),
                    payload.get("status", "draft"),
                    payload.get("duration_minutes"),
                    payload.get("certificate_valid_months", 12),
                    user_id,
                    created_at,
                    created_at,
                ),
            )
            for locale, strings in (payload.get("locales") or {}).items():
                conn.execute(
                    """
                    insert into course_i18n(course_id, locale, title, summary)
                    values (?, ?, ?, ?)
                    """,
                    (course_id, locale, strings.get("title"), strings.get("summary")),
                )
            for index, module in enumerate(payload.get("modules", []), start=1):
                module_id = str(uuid4())
                conn.execute(
                    """
                    insert into modules(id, course_id, type, position, passing_score, shuffle)
                    values (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        module_id,
                        course_id,
                        module.get("type"),
                        module.get("position", index),
                        module.get("passing_score"),
                        1 if module.get("shuffle", True) else 0,
                    ),
                )
                for locale, content in (module.get("content") or {}).items():
                    conn.execute(
                        """
                        insert into module_i18n(module_id, locale, title, body_md, video_url)
                        values (?, ?, ?, ?, ?)
                        """,
                        (
                            module_id,
                            locale,
                            content.get("title"),
                            content.get("body_md"),
                            content.get("video_url"),
                        ),
                    )
                for question in module.get("questions", []):
                    question_id = str(uuid4())
                    conn.execute(
                        """
                        insert into quiz_questions(id, module_id, body, type, explanation)
                        values (?, ?, ?, ?, ?)
                        """,
                        (
                            question_id,
                            module_id,
                            question.get("body"),
                            question.get("type", "single"),
                            question.get("explanation"),
                        ),
                    )
                    for option in question.get("options", []):
                        option_id = str(uuid4())
                        conn.execute(
                            """
                            insert into quiz_options(id, question_id, body, is_correct)
                            values (?, ?, ?, ?)
                            """,
                            (
                                option_id,
                                question_id,
                                option.get("body"),
                                1 if option.get("is_correct") else 0,
                            ),
                        )
        db.add_audit(org_id, user_id, "course.create", course_id, {"code": payload.get("code")})
        json_response(self, HTTPStatus.CREATED, {"course_id": course_id})

    def handle_list_courses(self) -> None:
        _, org_id, _ = require_auth(self)
        with db.get_conn(readonly=True) as conn:
            rows = conn.execute(
                """
                select c.*, group_concat(ci.locale || ':' || ci.title, '|') as locales
                from courses c
                left join course_i18n ci on ci.course_id = c.id
                group by c.id
                order by c.created_at desc
                """,
            ).fetchall()
        courses = []
        for row in rows:
            locales = {}
            if row["locales"]:
                for entry in row["locales"].split("|"):
                    locale, title = entry.split(":", 1)
                    locales[locale] = {"title": title}
            courses.append(
                {
                    "id": row["id"],
                    "code": row["code"],
                    "status": row["status"],
                    "certificate_valid_months": row["certificate_valid_months"],
                    "duration_minutes": row["duration_minutes"],
                    "locales": locales,
                }
            )
        json_response(self, HTTPStatus.OK, {"courses": courses})

    def handle_assignments(self) -> None:
        user_id, org_id, role = require_auth(self)
        if role not in {"admin", "super_admin"}:
            raise AuthError("Only admins can assign courses")
        payload = parse_body(self)
        assigned_to: List[str] = payload.get("assigned_to") or []
        due_at = payload.get("due_at")
        now = db.now_ts()
        created: List[str] = []
        audit_payloads: List[Tuple[str, str]] = []
        with db.get_conn() as conn:
            for participant in assigned_to:
                assignment_id = str(uuid4())
                conn.execute(
                    """
                    insert into assignments(id, org_id, course_id, assigned_by, assigned_to, due_at, created_at)
                    values (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        assignment_id,
                        org_id,
                        payload.get("course_id"),
                        user_id,
                        participant,
                        due_at,
                        now,
                    ),
                )
                created.append(assignment_id)
                audit_payloads.append((assignment_id, participant))
        for assignment_id, participant in audit_payloads:
            db.add_audit(
                org_id,
                user_id,
                "assignment.create",
                assignment_id,
                {"course_id": payload.get("course_id"), "assigned_to": participant, "due_at": due_at},
            )
        json_response(self, HTTPStatus.CREATED, {"assignments": created})

    def handle_list_assignments(self) -> None:
        user_id, org_id, role = require_auth(self)
        parsed = urllib.parse.urlparse(self.path)
        status_filter = (params.get("status") or [None])[0]
        with db.get_conn(readonly=True) as conn:
            rows = conn.execute(
                """
                select a.*, c.code, c.certificate_valid_months,
                       count(distinct p.id) as progress_count,
                       cert.id as certificate_id
                from assignments a
                join courses c on c.id = a.course_id
                left join progress p on p.assignment_id = a.id
                left join certificates cert on cert.assignment_id = a.id
                where a.org_id = ? and (a.assigned_to = ? or ? in ('admin','super_admin'))
                group by a.id
                order by a.created_at desc
                """,
                (org_id, user_id, role),
            ).fetchall()
        result = []
        for row in rows:
            status = build_status(row)
            if status_filter and status_filter != status:
                continue
            result.append(
                {
                    "id": row["id"],
                    "course_id": row["course_id"],
                    "course_code": row["code"],
                    "assigned_to": row["assigned_to"],
                    "due_at": row["due_at"],
                    "status": status,
                    "certificate_id": row.get("certificate_id"),
                }
            )
        json_response(self, HTTPStatus.OK, {"assignments": result})

    def handle_progress(self) -> None:
        user_id, org_id, role = require_auth(self)
        payload = parse_body(self)
        assignment_id = payload.get("assignment_id")
        module_id = payload.get("module_id")
        if not assignment_id or not module_id:
            raise ValueError("assignment_id and module_id are required")
        now = db.now_ts()
        with db.get_conn() as conn:
            assignment = conn.execute(
                "select assigned_to from assignments where id = ?",
                (assignment_id,),
            ).fetchone()
            if not assignment:
                raise ValueError("Assignment not found")
            if assignment["assigned_to"] != user_id and role not in {"admin", "super_admin"}:
                raise AuthError("Not allowed")
            existing = conn.execute(
                "select id, attempts from progress where assignment_id = ? and module_id = ?",
                (assignment_id, module_id),
            ).fetchone()
            if existing:
                conn.execute(
                    """
                    update progress set completed_at = coalesce(?, completed_at), last_pos = ?, score = coalesce(?, score), attempts = ?, updated_at = ?
                    where id = ?
                    """,
                    (
                        payload.get("completed_at"),
                        payload.get("last_pos"),
                        payload.get("score"),
                        payload.get("attempts", existing["attempts"]),
                        now,
                        existing["id"],
                    ),
                )
                progress_id = existing["id"]
            else:
                progress_id = str(uuid4())
                conn.execute(
                    """
                    insert into progress(id, assignment_id, module_id, completed_at, last_pos, score, attempts, updated_at)
                    values (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        progress_id,
                        assignment_id,
                        module_id,
                        payload.get("completed_at"),
                        payload.get("last_pos"),
                        payload.get("score"),
                        payload.get("attempts", 1),
                        now,
                    ),
                )
        json_response(self, HTTPStatus.OK, {"progress_id": progress_id})

    def handle_quiz_submit(self) -> None:
        user_id, _, _ = require_auth(self)
        payload = parse_body(self)
        assignment_id = payload.get("assignment_id")
        module_id = payload.get("module_id")
        answers = payload.get("answers") or {}
        with db.get_conn(readonly=True) as conn:
            questions = conn.execute(
                "select id, type, explanation from quiz_questions where module_id = ?",
                (module_id,),
            ).fetchall()
            if not questions:
                raise ValueError("Quiz not found")
            options = conn.execute(
                "select * from quiz_options where question_id in (select id from quiz_questions where module_id = ?)",
                (module_id,),
            ).fetchall()
            module = conn.execute(
                "select passing_score from modules where id = ?",
                (module_id,),
            ).fetchone()
        correct_map: Dict[str, List[str]] = {}
        for option in options:
            correct_map.setdefault(option["question_id"], []).append(option["id"] if option["is_correct"] else None)
        score = 0
        explanations: Dict[str, Any] = {}
        for question in questions:
            expected = {opt for opt in correct_map.get(question["id"], []) if opt}
            provided = set(map(str, answers.get(question["id"], [])))
            if question["type"] == "single" and len(provided) > 1:
                provided = {next(iter(provided))}
            if provided == expected:
                score += 1
            explanations[question["id"]] = {
                "correct": list(expected),
                "your_answer": list(provided),
                "explanation": question.get("explanation"),
            }
        percent = int((score / max(len(questions), 1)) * 100)
        passed = percent >= (module["passing_score"] or 0)
        self.handle_progress_update(assignment_id, module_id, percent, passed)
        json_response(
            self,
            HTTPStatus.OK,
            {"score": percent, "passed": passed, "details": explanations},
        )

    def handle_progress_update(self, assignment_id: str, module_id: str, score: int, passed: bool) -> None:
        now = db.now_ts()
        with db.get_conn() as conn:
            existing = conn.execute(
                "select id, attempts from progress where assignment_id = ? and module_id = ?",
                (assignment_id, module_id),
            ).fetchone()
            completed_at = now if passed else None
            if existing:
                conn.execute(
                    """
                    update progress set score = ?, attempts = attempts + 1, completed_at = coalesce(completed_at, ?), updated_at = ?
                    where id = ?
                    """,
                    (score, completed_at, now, existing["id"]),
                )
            else:
                conn.execute(
                    """
                    insert into progress(id, assignment_id, module_id, completed_at, score, attempts, updated_at)
                    values (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (str(uuid4()), assignment_id, module_id, completed_at, score, 1, now),
                )

    def handle_issue_certificate(self) -> None:
        user_id, org_id, role = require_auth(self)
        payload = parse_body(self)
        assignment_id = payload.get("assignment_id")
        if role not in {"admin", "super_admin"}:
            raise AuthError("Only admins can issue certificates")
        with db.get_conn() as conn:
            assignment = conn.execute(
                "select a.*, c.certificate_valid_months from assignments a join courses c on c.id = a.course_id where a.id = ?",
                (assignment_id,),
            ).fetchone()
            if not assignment:
                raise ValueError("Assignment not found")
            modules = conn.execute(
                "select id, type, passing_score from modules where course_id = ?",
                (assignment["course_id"],),
            ).fetchall()
            progress = conn.execute(
                "select module_id, completed_at, score from progress where assignment_id = ?",
                (assignment_id,),
            ).fetchall()
        progress_map = {row["module_id"]: row for row in progress}
        for module in modules:
            if module["type"] == "quiz":
                entry = progress_map.get(module["id"])
                if not entry or (module["passing_score"] and (entry.get("score") or 0) < module["passing_score"]):
                    raise ValueError("Quiz requirements not met")
            else:
                if module["id"] not in progress_map or not progress_map[module["id"]].get("completed_at"):
                    raise ValueError("Module completion missing")
        issued_at = datetime.utcnow()
        expiry = db.calculate_expiry(issued_at, assignment["certificate_valid_months"] or 12)
        cert_id = str(uuid4())
        with db.get_conn() as conn:
            conn.execute(
                """
                insert into certificates(id, assignment_id, issued_at, expires_at, pdf_url)
                values (?, ?, ?, ?, ?)
                """,
                (
                    cert_id,
                    assignment_id,
                    issued_at.isoformat(timespec="seconds") + "Z",
                    expiry.isoformat(timespec="seconds") + "Z",
                    payload.get("pdf_url"),
                ),
            )
        db.add_audit(org_id, user_id, "certificate.issue", assignment_id, {"certificate_id": cert_id})
        json_response(self, HTTPStatus.CREATED, {"certificate_id": cert_id})

    def handle_report(self) -> None:
        user_id, org_id, role = require_auth(self)
        if role not in {"admin", "super_admin"}:
            raise AuthError("Only admins can export reports")
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        with db.get_conn(readonly=True) as conn:
            rows = conn.execute(
                """
                select a.id as assignment_id, u.email, c.code, cert.issued_at, cert.expires_at
                from assignments a
                join users u on u.id = a.assigned_to
                join courses c on c.id = a.course_id
                left join certificates cert on cert.assignment_id = a.id
                where a.org_id = ?
                order by a.created_at desc
                """,
                (org_id,),
            ).fetchall()
        headers = ["assignment_id", "participant_email", "course_code", "issued_at", "expires_at"]
        lines = [",".join(headers)]
        for row in rows:
            lines.append(
                ",".join(
                    [
                        row.get("assignment_id", ""),
                        row.get("email", ""),
                        row.get("code", ""),
                        row.get("issued_at", ""),
                        row.get("expires_at", ""),
                    ]
                )
            )
        data = "\n".join(lines).encode()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/csv")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_demo_setup(self) -> None:
        payload = parse_body(self)
        seed = payload.get("seed", "demo")
        org_id = str(uuid4())
        admin_id = str(uuid4())
        participant_id = str(uuid4())
        created_at = db.now_ts()
        with db.get_conn() as conn:
            conn.execute(
                "insert into orgs(id, name, billing_plan, created_at) values (?, ?, 'per_seat', ?)",
                (org_id, f"Demo Org {seed}", created_at),
            )
            admin_hash = hash_password("password123")
            participant_hash = hash_password("password123")
            conn.execute(
                "insert into users(id, email, password_hash, name, created_at, updated_at) values (?, ?, ?, ?, ?, ?)",
                (admin_id, f"admin-{seed}@example.com", admin_hash, "Demo Admin", created_at, created_at),
            )
            conn.execute(
                "insert into users(id, email, password_hash, name, created_at, updated_at) values (?, ?, ?, ?, ?, ?)",
                (
                    participant_id,
                    f"participant-{seed}@example.com",
                    participant_hash,
                    "Demo Participant",
                    created_at,
                    created_at,
                ),
            )
            conn.execute(
                "insert into org_members(org_id, user_id, role) values (?, ?, 'admin')",
                (org_id, admin_id),
            )
            conn.execute(
                "insert into org_members(org_id, user_id, role) values (?, ?, 'participant')",
                (org_id, participant_id),
            )
        json_response(
            self,
            HTTPStatus.CREATED,
            {
                "org_id": org_id,
                "admin": {"user_id": admin_id, "email": f"admin-{seed}@example.com", "password": "password123"},
                "participant": {
                    "user_id": participant_id,
                    "email": f"participant-{seed}@example.com",
                    "password": "password123",
                },
            },
        )

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003 - BaseHTTPRequestHandler API
        return  # Silence default logging


def run(host: str = "0.0.0.0", port: int = 8000) -> None:
    server = HTTPServer((host, port), TrainingRequestHandler)
    print(f"Training server listening on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run()
