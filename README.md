# AILEARNING Compliance Training Platform

This repository contains a working prototype implementation of the compliance & safety training MVP. It includes:

- **Documentation** outlining the product vision, MVP scope, and delivery plan (`docs/`).
- **Backend service** implemented with Python standard libraries (`backend/`) that covers multi-tenant course delivery, assignments, quizzes, certificates, audit logs, and CSV reporting.

## Getting started

1. **Run the backend**

   ```bash
   python -m backend.src.server
   ```

   The API listens on `http://localhost:8000`. Use the `/setup/demo` endpoint to create a demo organisation with sample users, then authenticate using `/auth/login`.

2. **Explore the API**

   Use `curl` or any REST client to exercise the flows:

   - Create or list courses
   - Assign courses to participants
   - Submit progress and quizzes
   - Issue certificates and export completion reports

Refer to the backend README for a detailed endpoint matrix and payload samples.
