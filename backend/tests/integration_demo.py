"""Happy-path integration flow exercising the backend API over HTTP."""
from __future__ import annotations

import http.client
import json
import threading
import time
from datetime import datetime
from importlib import reload
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import sys

sys.path.append(str(Path(__file__).resolve().parents[2]))

from backend.src import db
from backend.src.server import TrainingRequestHandler
from http.server import HTTPServer

DB_FILE = Path(__file__).resolve().parents[1] / "data" / "app.db"
if DB_FILE.exists():
    DB_FILE.unlink()

# Ensure database is re-initialised
reload(db)


class ServerThread(threading.Thread):
    def __init__(self, host: str = "127.0.0.1", port: int = 8765) -> None:
        super().__init__(daemon=True)
        self.server = HTTPServer((host, port), TrainingRequestHandler)

    def run(self) -> None:  # pragma: no cover - thread wrapper
        self.server.serve_forever()

    def stop(self) -> None:
        self.server.shutdown()


def request(method: str, path: str, body: Optional[Dict[str, Any]] = None, token: Optional[str] = None) -> Tuple[int, Dict[str, Any]]:
    conn = http.client.HTTPConnection("127.0.0.1", 8765)
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    payload = json.dumps(body).encode() if body is not None else None
    conn.request(method, path, body=payload, headers=headers)
    response = conn.getresponse()
    data = response.read()
    conn.close()
    try:
        parsed = json.loads(data.decode()) if data else {}
    except json.JSONDecodeError:
        parsed = {"raw": data.decode()}
    return response.status, parsed


if __name__ == "__main__":
    server = ServerThread()
    server.start()
    time.sleep(0.2)

    # Register an admin with a new organisation
    status, payload = request(
        "POST",
        "/auth/register",
        {
            "email": "admin@example.com",
            "password": "StrongPass!123",
            "name": "Admin User",
            "org_name": "Safety First",
        },
    )
    assert status == 201, payload
    admin_token = payload["token"]
    org_id = payload["org_id"]

    # Register a participant and attach to the same organisation
    status, participant = request(
        "POST",
        "/auth/register",
        {
            "email": "participant@example.com",
            "password": "StrongPass!123",
            "name": "Participant One",
            "org_id": org_id,
            "role": "participant",
        },
    )
    assert status == 201, participant
    participant_id = participant["user_id"]

    # Create a simple course with one article and one quiz module
    status, course = request(
        "POST",
        "/courses",
        {
            "code": "FSE-101",
            "status": "published",
            "duration_minutes": 30,
            "certificate_valid_months": 12,
            "locales": {
                "nb": {"title": "Elsikkerhet", "summary": "Grunnkurs"},
                "en": {"title": "Electrical Safety", "summary": "Introduction"},
            },
            "modules": [
                {
                    "type": "article",
                    "position": 1,
                    "content": {
                        "en": {"title": "Intro", "body_md": "## Welcome"},
                        "nb": {"title": "Intro", "body_md": "## Velkommen"},
                    },
                },
                {
                    "type": "quiz",
                    "position": 2,
                    "passing_score": 80,
                    "questions": [
                        {
                            "body": "What is the safe voltage limit?",
                            "type": "single",
                            "options": [
                                {"body": "50V", "is_correct": True},
                                {"body": "230V", "is_correct": False},
                            ],
                        }
                    ],
                },
            ],
        },
        token=admin_token,
    )
    assert status == 201, course
    course_id = course["course_id"]

    # Assign the course to the participant
    status, assignments = request(
        "POST",
        "/assignments",
        {
            "course_id": course_id,
            "assigned_to": [participant_id],
            "due_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        },
        token=admin_token,
    )
    assert status == 201, assignments
    assignment_id = assignments["assignments"][0]

    # Participant logs in
    status, login = request(
        "POST",
        "/auth/login",
        {"email": "participant@example.com", "password": "StrongPass!123", "org_id": org_id},
    )
    assert status == 200, login
    participant_token = login["token"]

    # Participant completes article module
    with db.get_conn(readonly=True) as conn:
        article_module = conn.execute(
            "select id from modules where course_id = ? and type = 'article'",
            (course_id,),
        ).fetchone()["id"]
        quiz_module = conn.execute(
            "select id from modules where course_id = ? and type = 'quiz'",
            (course_id,),
        ).fetchone()["id"]
        question = conn.execute(
            "select id from quiz_questions where module_id = ?",
            (quiz_module,),
        ).fetchone()["id"]
        correct_option = conn.execute(
            "select id from quiz_options where question_id = ? and is_correct = 1",
            (question,),
        ).fetchone()["id"]

    status, progress = request(
        "POST",
        "/progress",
        {
            "assignment_id": assignment_id,
            "module_id": article_module,
            "completed_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        },
        token=participant_token,
    )
    assert status == 200, progress

    # Submit quiz answers
    status, quiz_result = request(
        "POST",
        "/quiz/submit",
        {
            "assignment_id": assignment_id,
            "module_id": quiz_module,
            "answers": {question: [correct_option]},
        },
        token=participant_token,
    )
    assert status == 200 and quiz_result["passed"], quiz_result

    # Admin issues certificate
    status, certificate = request(
        "POST",
        "/certificates/issue",
        {"assignment_id": assignment_id, "pdf_url": "https://example.com/certs/demo.pdf"},
        token=admin_token,
    )
    assert status == 201, certificate

    # Export CSV report
    conn = http.client.HTTPConnection("127.0.0.1", 8765)
    conn.request(
        "GET",
        "/reports/completions.csv",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    response = conn.getresponse()
    assert response.status == 200, response.read()
    csv_content = response.read().decode()
    conn.close()
    assert "demo.pdf" in csv_content or "FSE-101" in csv_content

    server.stop()
    print("Integration flow completed successfully.")
