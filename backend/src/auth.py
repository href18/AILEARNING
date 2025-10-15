"""Authentication helpers with password hashing and token signing."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Dict

SECRET = os.environ.get("TRAINING_APP_SECRET", "dev-secret-key")
TOKEN_TTL_MINUTES = 60 * 8


@dataclass
class Token:
    user_id: str
    org_id: str
    role: str
    exp: datetime

    def to_dict(self) -> Dict[str, Any]:
        return {
            "user_id": self.user_id,
            "org_id": self.org_id,
            "role": self.role,
            "exp": self.exp.isoformat(timespec="seconds") + "Z",
        }


class AuthError(Exception):
    pass


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    hashed = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return base64.urlsafe_b64encode(salt + hashed).decode()


def verify_password(password: str, stored: str) -> bool:
    raw = base64.urlsafe_b64decode(stored.encode())
    salt, hashed = raw[:16], raw[16:]
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return hmac.compare_digest(hashed, check)


def sign_token(user_id: str, org_id: str, role: str) -> str:
    payload = Token(
        user_id=user_id,
        org_id=org_id,
        role=role,
        exp=datetime.utcnow() + timedelta(minutes=TOKEN_TTL_MINUTES),
    ).to_dict()
    data = json.dumps(payload, separators=(",", ":")).encode()
    sig = hmac.new(SECRET.encode(), data, hashlib.sha256).digest()
    return ".".join(
        base64.urlsafe_b64encode(part).decode().rstrip("=")
        for part in (data, sig)
    )


def verify_token(token: str) -> Token:
    try:
        payload_b64, sig_b64 = token.split(".")
        data = base64.urlsafe_b64decode(payload_b64 + "==")
        sig = base64.urlsafe_b64decode(sig_b64 + "==")
    except Exception as exc:  # pragma: no cover - defensive
        raise AuthError("Invalid token format") from exc
    expected = hmac.new(SECRET.encode(), data, hashlib.sha256).digest()
    if not hmac.compare_digest(expected, sig):
        raise AuthError("Invalid token signature")
    payload = json.loads(data.decode())
    exp = datetime.fromisoformat(payload["exp"].rstrip("Z"))
    if exp < datetime.utcnow():
        raise AuthError("Token expired")
    return Token(
        user_id=payload["user_id"],
        org_id=payload["org_id"],
        role=payload["role"],
        exp=exp,
    )
