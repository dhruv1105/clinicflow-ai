"""
ClinicFlow AI — Main Server
FastAPI + ADK with role-based login.

Flow:
  / → login page
  POST /login → validate email/password → create ADK session with role in state
              → redirect to /dev-ui (ADK Web UI)
  Agent reads {role} and {user_name} from session state in its instructions
"""

import os
import uuid
import hashlib
import uvicorn
import psycopg2
import psycopg2.extras
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from google.adk.cli.fast_api import get_fast_api_app
from fastapi.routing import APIRoute
from fastapi.responses import HTMLResponse
from google.adk.sessions import DatabaseSessionService

load_dotenv()

# ─── DB Config ─────────────────────────────────────────────────
DB_CONFIG = {
    "host":     os.getenv("DB_HOST"),
    "port":     os.getenv("DB_PORT", "5432"),
    "dbname":   os.getenv("DB_NAME", "postgres"),
    "user":     os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "sslmode":  "require",
}

# ─── Simple session store (maps session cookie → ADK session info) ──
SESSION_STORE: dict[str, dict] = {}

# ─── ADK App Setup ──────────────────────────────────────────────
AGENT_DIR   = os.path.dirname(os.path.abspath(__file__))
SESSION_URI = "sqlite+aiosqlite:///./clinicflow_sessions.db"
APP_NAME = "agents"

app: FastAPI = get_fast_api_app(
    agents_dir=AGENT_DIR,
    session_service_uri=SESSION_URI,
    allow_origins=["*"],
    web=True,
)

async def login_page():
    index_path = Path(__file__).parent / "frontend" / "index.html"
    return HTMLResponse(content=index_path.read_text())

app.router.routes.insert(0, APIRoute("/", endpoint=login_page, methods=["GET"]))

# ─── Helpers ────────────────────────────────────────────────────

def _db():
    return psycopg2.connect(**DB_CONFIG)


def _verify_login(email: str, password: str) -> dict | None:
    """Verify email/password against user_accounts table."""
    import bcrypt
    try:
        conn = _db()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT ua.user_id, ua.role, ua.linked_id,
                       ua.password_hash,
                       CASE ua.role
                           WHEN 'doctor' THEN d.name
                           WHEN 'patient' THEN p.name
                       END AS user_name
                FROM user_accounts ua
                LEFT JOIN doctors d ON ua.role='doctor' AND d.doctor_id=ua.linked_id
                LEFT JOIN patients p ON ua.role='patient' AND p.patient_id=ua.linked_id
                WHERE ua.email = %s
            """, (email,))
            row = cur.fetchone()
        conn.close()

        if not row:
            return None

        # Verify password
        if bcrypt.checkpw(password.encode(), row["password_hash"].encode()):
            return dict(row)
        return None
    except Exception as e:
        print(f"Login error: {e}")
        return None


async def _create_adk_session_with_state(user_id: str, initial_state: dict) -> str:
    """Create an ADK session pre-populated with role + user info."""
    import httpx
    session_id = str(uuid.uuid4())
    # Use ADK's internal session endpoint to set initial state
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"http://localhost:8000/apps/agents/users/{user_id}/sessions/{session_id}",
                json={"state": initial_state},   # ADK expects {"state": {...}}
                timeout=5,
            )
            if resp.status_code not in (200, 201):
                print(f"Session creation returned {resp.status_code}")
    except Exception as e:
        print(f"ADK session pre-creation failed (will be created on first message): {e}")
    return session_id


# ─── Routes ─────────────────────────────────────────────────────

@app.post("/login")
async def login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
):
    user = _verify_login(email, password)

    if not user:
        # Redirect back to login with error
        return RedirectResponse("/?error=invalid", status_code=303)

    # Map role → linked entity ID
    user_id = f"{user['role']}_{user['linked_id']}"
    role    = user["role"]
    name    = user["user_name"] or email

    # Initial session state — agent reads these as {role}, {user_name}, {user_id}
    initial_state = {
        "role":       role,
        "user_name":  name,
        "user_id":    str(user["linked_id"]),
        "user_email": email,
    }

    # Store in our session store
    cookie_id = str(uuid.uuid4())
    SESSION_STORE[cookie_id] = {
        **initial_state,
        "adk_user_id": user_id,
    }
    from shared_state import set_user
    set_user(user_id, initial_state)


    # Redirect to ADK Dev UI
    response = RedirectResponse(
        f"/dev-ui/?app=agents&userId={user_id}",
        status_code=303
    )
    response.set_cookie("cf_session", cookie_id, httponly=True, samesite="lax")
    return response


@app.get("/logout")
async def logout(request: Request):
    cookie_id = request.cookies.get("cf_session", "")
    SESSION_STORE.pop(cookie_id, None)
    response = RedirectResponse("/", status_code=303)
    response.delete_cookie("cf_session")
    return response


@app.get("/me")
async def me(request: Request):
    """Let agent tools check who is logged in."""
    cookie_id = request.cookies.get("cf_session", "")
    data = SESSION_STORE.get(cookie_id, {})
    return JSONResponse({
        "role":      data.get("role", "unknown"),
        "user_name": data.get("user_name", ""),
        "user_id":   data.get("user_id", ""),
        "email":     data.get("user_email", ""),
    })


def get_current_user_from_session(cookie_id: str) -> dict:
    """Helper imported by agent tools."""
    return SESSION_STORE.get(cookie_id, {})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)