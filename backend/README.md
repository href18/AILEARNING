# Compliance Training Backend

This directory contains a lightweight backend implementation for the compliance & safety training MVP described in the project brief. The service is implemented purely with the Python standard library (SQLite + `http.server`) so it can run in restricted environments without external dependencies.

## Features

- Multi-tenant user + organisation model with role-based access (participant/admin/author/super_admin)
- Course catalogue with multilingual metadata and module definitions (video/article/quiz)
- Quiz engine supporting single- and multi-select questions with scoring + explanations
- Assignment flow: admins assign courses, participants track progress per module
- Certificate issuance with validity calculations and audit logging
- CSV compliance report export for audit-ready documentation
- Demo bootstrap endpoint to create sample data for quick testing
- Token-based authentication with HMAC signatures and PBKDF2 password hashing

## Running the server

```bash
python -m backend.src.server
```

The service listens on port `8000` by default. Set the `TRAINING_APP_SECRET` environment variable to change the token signing secret.

## API Overview

| Endpoint | Method | Description |
| --- | --- | --- |
| `/auth/register` | POST | Register a user, optionally creating a new organisation |
| `/auth/login` | POST | Login and receive a bearer token |
| `/courses` | POST | Create a course with modules (admin/author only) |
| `/courses` | GET | List courses |
| `/assignments` | POST | Assign a course to users (admin only) |
| `/assignments` | GET | List assignments filtered by status |
| `/progress` | POST | Update module progress |
| `/quiz/submit` | POST | Submit quiz answers and receive scoring |
| `/certificates/issue` | POST | Issue a certificate once completion criteria are met |
| `/reports/completions.csv` | GET | Export course completion report as CSV |
| `/setup/demo` | POST | Create a demo tenant with admin + participant |

Refer to `backend/src/server.py` for exact payload formats and behaviour.
