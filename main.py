"""
ClinicFlow AI — Main Server
FastAPI + ADK with role-based login and doctor session panel.

Routes:
  GET  /                          → Login page
  POST /login                     → Validate credentials → set shared state → redirect to ADK UI
  GET  /logout                    → Clear session
  GET  /me                        → Return current user info (JSON)
  GET  /session/{appointment_id}  → Doctor session panel (audio + prescription + mark complete)
  POST /api/session/{id}/audio    → Save audio segment (multipart)
  POST /api/session/{id}/prescription → Upload prescription image (multipart)
  POST /api/session/{id}/complete → Mark complete + run summarization pipeline
"""

import os
import uuid
import hashlib
import base64
import uvicorn
import psycopg2
import psycopg2.extras
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, Request, Form, UploadFile, File
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from google.adk.cli.fast_api import get_fast_api_app
from fastapi.routing import APIRoute
from fastapi.responses import HTMLResponse
from google.adk.sessions import DatabaseSessionService

load_dotenv()

# ─── DB Config ──────────────────────────────────────────────────
DB_CONFIG = {
    "host":     os.getenv("DB_HOST"),
    "port":     os.getenv("DB_PORT", "5432"),
    "dbname":   os.getenv("DB_NAME", "postgres"),
    "user":     os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "sslmode":  "require",
}

# ─── Simple session store (cookie → user data) ──────────────────
SESSION_STORE: dict[str, dict] = {}

# ─── ADK App Setup ──────────────────────────────────────────────
AGENT_DIR   = os.path.dirname(os.path.abspath(__file__))
SESSION_URI = "sqlite:///./clinicflow_sessions.db"

app: FastAPI = get_fast_api_app(
    agents_dir=AGENT_DIR,
    session_service_uri=SESSION_URI,
    allow_origins=["*"],
    web=True,
)

from fastapi.routing import APIRoute

async def login_page():
    index_path = Path(__file__).parent.parent / "support" / "frontend" / "index.html"
    return HTMLResponse(content=index_path.read_text())

app.router.routes.insert(0, APIRoute("/", endpoint=login_page, methods=["GET"]))


# ─── Helpers ────────────────────────────────────────────────────

def _db():
    return psycopg2.connect(**DB_CONFIG)


def _verify_login(email: str, password: str) -> dict | None:
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
        if bcrypt.checkpw(password.encode(), row["password_hash"].encode()):
            return dict(row)
        return None
    except Exception as e:
        print(f"Login error: {e}")
        return None


def _get_appointment_info(appointment_id: int) -> dict:
    """Fetch appointment + patient details for the session panel."""
    try:
        conn = _db()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT a.appointment_id, a.scheduled_at, a.reason, a.status,
                       a.summary_generated,
                       p.name AS patient_name, p.age, p.gender,
                       p.blood_group, p.allergies, p.chronic_conditions,
                       p.phone, p.patient_id
                FROM appointments a
                JOIN patients p ON a.patient_id = p.patient_id
                WHERE a.appointment_id = %s
            """, (appointment_id,))
            row = cur.fetchone()
        conn.close()
        return dict(row) if row else {}
    except Exception as e:
        print(f"Appointment fetch error: {e}")
        return {}


# ─── Auth Routes ───────────────────────────────────────────────── 

@app.post("/login")
async def login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
):
    user = _verify_login(email, password)
    if not user:
        return RedirectResponse("/?error=invalid", status_code=303)

    user_id = f"{user['role']}_{user['linked_id']}"
    role    = user["role"]
    name    = user["user_name"] or email

    initial_state = {
        "role":       role,
        "user_name":  name,
        "user_id":    str(user["linked_id"]),
        "user_email": email,
    }

    # Persist in cookie store
    cookie_id = str(uuid.uuid4())
    SESSION_STORE[cookie_id] = {**initial_state, "adk_user_id": user_id}

    # Persist in shared in-memory store — agent reads this as fallback
    from shared_state import set_user
    set_user(user_id, initial_state)

    response = RedirectResponse(
        f"/dev-ui/?app=agents&userId={user_id}",
        status_code=303,
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
    cookie_id = request.cookies.get("cf_session", "")
    data = SESSION_STORE.get(cookie_id, {})
    return JSONResponse({
        "role":      data.get("role", "unknown"),
        "user_name": data.get("user_name", ""),
        "user_id":   data.get("user_id", ""),
        "email":     data.get("user_email", ""),
    })


# ─── Session Panel Routes ────────────────────────────────────────

@app.get("/session/{appointment_id}", response_class=HTMLResponse)
async def session_panel(appointment_id: int, request: Request):
    """Doctor session panel — audio recording + prescription upload + mark complete."""
    appt = _get_appointment_info(appointment_id)
    if not appt:
        return HTMLResponse("<h2>Appointment not found</h2>", status_code=404)

    patient_name  = appt.get("patient_name", "Unknown")
    reason        = appt.get("reason", "")
    age           = appt.get("age", "")
    gender        = appt.get("gender", "")
    blood_group   = appt.get("blood_group", "")
    allergies     = appt.get("allergies", "None")
    chronic       = appt.get("chronic_conditions", "None")
    already_done  = appt.get("summary_generated", False)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Session — {patient_name}</title>
  <style>
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{
      font-family: 'Segoe UI', system-ui, sans-serif;
      background: linear-gradient(135deg, #0f2027, #203a43, #2c5364);
      min-height: 100vh; color: #e2e8f0; padding: 1.5rem;
    }}
    .header {{
      display: flex; align-items: center; gap: 1rem;
      margin-bottom: 1.5rem;
    }}
    .back-btn {{
      background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15);
      color: #94a3b8; padding: 0.4rem 0.8rem; border-radius: 6px;
      text-decoration: none; font-size: 0.82rem; cursor: pointer;
    }}
    h1 {{ font-size: 1.4rem; font-weight: 700; color: #fff; }}
    h1 span {{ color: #38bdf8; }}
    .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }}
    @media(max-width:700px) {{ .grid {{ grid-template-columns: 1fr; }} }}
    .card {{
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 14px; padding: 1.2rem;
    }}
    .card h2 {{
      font-size: 0.78rem; font-weight: 700; letter-spacing: 0.08em;
      color: #7dd3fc; text-transform: uppercase; margin-bottom: 0.8rem;
    }}
    .patient-row {{ display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 0.3rem; }}
    .badge {{
      background: rgba(56,189,248,0.12); border: 1px solid rgba(56,189,248,0.25);
      color: #bae6fd; font-size: 0.75rem; padding: 0.2rem 0.55rem; border-radius: 20px;
    }}
    .badge.red {{
      background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #fca5a5;
    }}
    .badge.yellow {{
      background: rgba(234,179,8,0.12); border-color: rgba(234,179,8,0.3); color: #fde047;
    }}
    .reason {{ color: #94a3b8; font-size: 0.85rem; margin-top: 0.4rem; }}
    /* Recording */
    .rec-controls {{ display: flex; gap: 0.7rem; margin-bottom: 0.8rem; flex-wrap: wrap; }}
    .btn {{
      padding: 0.55rem 1.1rem; border: none; border-radius: 8px;
      font-size: 0.85rem; font-weight: 600; cursor: pointer; transition: opacity 0.15s;
    }}
    .btn:disabled {{ opacity: 0.35; cursor: not-allowed; }}
    .btn-record  {{ background: #ef4444; color: #fff; }}
    .btn-stop    {{ background: #64748b; color: #fff; }}
    .btn-upload  {{ background: #0ea5e9; color: #fff; }}
    .btn-complete{{
      background: linear-gradient(135deg,#16a34a,#22c55e);
      color:#fff; width:100%; padding:0.75rem; font-size:0.95rem;
      border-radius:10px; border:none; cursor:pointer; font-weight:700;
      margin-top:0.5rem; transition: opacity 0.2s;
    }}
    .btn-complete:disabled {{ opacity: 0.4; cursor: not-allowed; }}
    .btn-emergency {{
      background: linear-gradient(135deg,#dc2626,#ef4444);
      color:#fff; width:100%; padding:0.65rem; font-size:0.88rem;
      border-radius:10px; border:none; cursor:pointer; font-weight:700;
      text-decoration: none; display:block; text-align:center; margin-top:0.6rem;
    }}
    .recording-dot {{
      display:inline-block; width:10px; height:10px; border-radius:50%;
      background:#ef4444; margin-right:6px;
      animation: pulse 1s infinite;
    }}
    @keyframes pulse {{ 0%,100%{{opacity:1}} 50%{{opacity:0.3}} }}
    .segments-list {{ list-style:none; margin-top:0.5rem; }}
    .segments-list li {{
      background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08);
      border-radius: 7px; padding: 0.4rem 0.7rem; font-size: 0.8rem;
      color: #94a3b8; margin-bottom: 0.35rem;
      display: flex; align-items: center; gap: 0.5rem;
    }}
    .segments-list li .ok {{ color: #4ade80; }}
    /* Prescription */
    .file-zone {{
      border: 2px dashed rgba(56,189,248,0.25); border-radius: 10px;
      padding: 1.2rem; text-align: center; cursor: pointer;
      transition: border-color 0.2s; margin-bottom: 0.8rem;
    }}
    .file-zone:hover {{ border-color: rgba(56,189,248,0.6); }}
    .file-zone p {{ color: #94a3b8; font-size: 0.82rem; }}
    .file-zone input {{ display: none; }}
    /* Status log */
    .status-log {{
      background: rgba(0,0,0,0.3); border-radius: 8px; padding: 0.7rem;
      font-size: 0.78rem; font-family: monospace; color: #94a3b8;
      min-height: 80px; max-height: 160px; overflow-y: auto;
      white-space: pre-wrap; grid-column: 1/-1;
    }}
    .status-log .ok  {{ color: #4ade80; }}
    .status-log .err {{ color: #f87171; }}
    .status-log .info{{ color: #38bdf8; }}
    .done-banner {{
      background: rgba(22,163,74,0.15); border: 1px solid rgba(34,197,94,0.3);
      border-radius: 10px; padding: 0.8rem 1rem; color: #4ade80;
      font-size: 0.88rem; grid-column: 1/-1; text-align:center;
    }}
  </style>
</head>
<body>

<div class="header">
  <a class="back-btn" onclick="history.back()">← Back</a>
  <h1>🩺 Session — <span>{patient_name}</span></h1>
</div>

{"<div class='done-banner'>✅ This appointment is already summarized. You can still record additional audio or upload a prescription.</div>" if already_done else ""}

<div class="grid">

  <!-- Patient Info -->
  <div class="card">
    <h2>Patient Details</h2>
    <div class="patient-row">
      <span class="badge">{age}y {gender}</span>
      <span class="badge">{blood_group}</span>
      {"<span class='badge red'>⚠ " + allergies + " allergy</span>" if allergies and allergies != "None" else ""}
      {"<span class='badge yellow'>" + chronic + "</span>" if chronic and chronic != "None" else ""}
    </div>
    <p class="reason">📋 Reason: {reason}</p>
  </div>

  <!-- Prescription Upload -->
  <div class="card">
    <h2>📄 Prescription Upload</h2>
    <div class="file-zone" onclick="document.getElementById('rxFile').click()">
      <p id="rxLabel">Click to select prescription image (JPG/PNG)</p>
      <input type="file" id="rxFile" accept="image/jpeg,image/png" onchange="handleRxSelect(event)"/>
    </div>
    <button class="btn btn-upload" id="rxBtn" disabled onclick="uploadPrescription()">
      Upload Prescription
    </button>
  </div>

  <!-- Audio Recording -->
  <div class="card">
    <h2>🎙 Audio Recording</h2>
    <div class="rec-controls">
      <button class="btn btn-record" id="startBtn" onclick="startRecording()">⏺ Start Recording</button>
      <button class="btn btn-stop" id="stopBtn" disabled onclick="stopAndSave()">⏹ Stop & Save</button>
    </div>
    <p id="recStatus" style="font-size:0.8rem;color:#94a3b8;margin-bottom:0.5rem;"></p>
    <ul class="segments-list" id="segmentsList"></ul>
  </div>

  <!-- Mark Complete -->
  <div class="card">
    <h2>✅ Complete Session</h2>
    <p style="font-size:0.82rem;color:#94a3b8;margin-bottom:0.8rem;">
      Marks appointment done. Triggers: transcription → diagnosis → patient Telegram notification.
    </p>
    <button class="btn-complete" id="completeBtn" onclick="markComplete()">
      Mark Appointment Complete & Summarize
    </button>
    <a href="tel:112" class="btn-emergency">🚨 Emergency — Call 112 (Ambulance)</a>
  </div>

  <!-- Status Log -->
  <div class="status-log" id="statusLog">Ready. Waiting for actions...\n</div>

</div>

<script>
const APPT_ID = {appointment_id};
let mediaRecorder = null;
let audioChunks   = [];
let segmentCount  = 0;
let rxFile        = null;

function log(msg, cls='') {{
  const el = document.getElementById('statusLog');
  const line = document.createElement('span');
  line.className = cls;
  line.textContent = msg + '\\n';
  el.appendChild(line);
  el.scrollTop = el.scrollHeight;
}}

// ── Audio Recording ──────────────────────────────────────────────

async function startRecording() {{
  try {{
    const stream = await navigator.mediaDevices.getUserMedia({{ audio: true }});
    audioChunks = [];
    mediaRecorder = new MediaRecorder(stream, {{ mimeType: 'audio/webm' }});
    mediaRecorder.ondataavailable = e => audioChunks.push(e.data);
    mediaRecorder.start();
    document.getElementById('startBtn').disabled = true;
    document.getElementById('stopBtn').disabled  = false;
    document.getElementById('recStatus').innerHTML =
      '<span class="recording-dot"></span>Recording...';
    log('Recording started.', 'info');
  }} catch(e) {{
    log('Microphone access denied: ' + e.message, 'err');
  }}
}}

async function stopAndSave() {{
  if (!mediaRecorder) return;
  mediaRecorder.stop();
  mediaRecorder.stream.getTracks().forEach(t => t.stop());
  document.getElementById('startBtn').disabled = false;
  document.getElementById('stopBtn').disabled  = true;
  document.getElementById('recStatus').textContent = 'Processing...';

  await new Promise(r => setTimeout(r, 300)); // let ondataavailable fire

  const blob   = new Blob(audioChunks, {{ type: 'audio/webm' }});
  const reader = new FileReader();
  reader.onload = async () => {{
    const b64 = reader.result.split(',')[1];
    segmentCount++;
    log(`Uploading segment ${{segmentCount}}...`, 'info');
    const resp = await fetch(`/api/session/${{APPT_ID}}/audio`, {{
      method: 'POST',
      headers: {{ 'Content-Type': 'application/json' }},
      body: JSON.stringify({{ audio_base64: b64, order_num: segmentCount }})
    }});
    const data = await resp.json();
    if (data.status === 'saved') {{
      log(`✓ Segment ${{segmentCount}} saved (segment_id: ${{data.segment_id}})`, 'ok');
      const li = document.createElement('li');
      li.innerHTML = `<span class="ok">✓</span> Segment ${{segmentCount}} — saved`;
      document.getElementById('segmentsList').appendChild(li);
    }} else {{
      log(`✗ Segment ${{segmentCount}} failed: ${{data.error || JSON.stringify(data)}}`, 'err');
    }}
    document.getElementById('recStatus').textContent = '';
  }};
  reader.readAsDataURL(blob);
}}

// ── Prescription Upload ──────────────────────────────────────────

function handleRxSelect(e) {{
  rxFile = e.target.files[0];
  if (rxFile) {{
    document.getElementById('rxLabel').textContent = '📎 ' + rxFile.name;
    document.getElementById('rxBtn').disabled = false;
  }}
}}

async function uploadPrescription() {{
  if (!rxFile) return;
  log('Uploading prescription...', 'info');
  document.getElementById('rxBtn').disabled = true;
  const reader = new FileReader();
  reader.onload = async () => {{
    const b64      = reader.result.split(',')[1];
    const mimeType = rxFile.type || 'image/jpeg';
    const resp = await fetch(`/api/session/${{APPT_ID}}/prescription`, {{
      method: 'POST',
      headers: {{ 'Content-Type': 'application/json' }},
      body: JSON.stringify({{ image_base64: b64, mime_type: mimeType }})
    }});
    const data = await resp.json();
    if (data.status === 'uploaded') {{
      log('✓ Prescription uploaded successfully.', 'ok');
    }} else {{
      log('✗ Prescription upload failed: ' + (data.error || JSON.stringify(data)), 'err');
      document.getElementById('rxBtn').disabled = false;
    }}
  }};
  reader.readAsDataURL(rxFile);
}}

// ── Mark Complete ────────────────────────────────────────────────

async function markComplete() {{
  const btn = document.getElementById('completeBtn');
  btn.disabled = true;
  btn.textContent = 'Processing pipeline...';
  log('Marking appointment complete...', 'info');

  const resp = await fetch(`/api/session/${{APPT_ID}}/complete`, {{
    method: 'POST',
    headers: {{ 'Content-Type': 'application/json' }}
  }});
  const data = await resp.json();

  if (data.error) {{
    log('✗ Error: ' + data.error, 'err');
    btn.disabled = false;
    btn.textContent = 'Mark Appointment Complete & Summarize';
    return;
  }}

  log('✓ Appointment marked complete.', 'ok');
  log('Running summarization pipeline...', 'info');

  if (data.summary) {{
    const s = data.summary;
    log('✓ Summary generated!', 'ok');
    log('  Diagnosis : ' + (s.diagnosis || '—'), 'ok');
    log('  Follow-up : ' + (s.follow_up  || '—'), 'ok');
    log('  Audio segments processed: ' + (s.audio_segments_processed || 0), 'info');
    log('  Prescription OCR: ' + (s.prescription_extracted ? 'Yes' : 'No'), 'info');
    log('  Telegram notification: ' + JSON.stringify(s.notification_sent || {{}}), 'info');
    btn.textContent = '✓ Session Complete';
  }} else {{
    log('⚠ Summarization returned: ' + JSON.stringify(data), 'info');
    btn.disabled = false;
    btn.textContent = 'Retry Summarization';
  }}
}}
</script>
</body>
</html>"""
    return HTMLResponse(content=html)


# ─── Session API Endpoints ───────────────────────────────────────

@app.post("/api/session/{appointment_id}/audio")
async def api_save_audio(appointment_id: int, request: Request):
    """Receive base64 audio from session panel, save to GCS + DB."""
    from agents.session_agent import save_audio_segment_base64
    body = await request.json()
    audio_b64 = body.get("audio_base64", "")
    order_num  = body.get("order_num", 1)
    mime_type  = body.get("mime_type", "audio/webm")

    if not audio_b64:
        return JSONResponse({"error": "Missing audio_base64"}, status_code=400)

    result = save_audio_segment_base64(appointment_id, audio_b64, order_num, mime_type)
    return JSONResponse(result)


@app.post("/api/session/{appointment_id}/prescription")
async def api_upload_prescription(appointment_id: int, request: Request):
    """Receive base64 image from session panel, upload to GCS + DB."""
    from agents.session_agent import upload_prescription_base64
    body      = await request.json()
    image_b64 = body.get("image_base64", "")
    mime_type = body.get("mime_type", "image/jpeg")

    if not image_b64:
        return JSONResponse({"error": "Missing image_base64"}, status_code=400)

    result = upload_prescription_base64(appointment_id, image_b64, mime_type)
    return JSONResponse(result)


@app.post("/api/session/{appointment_id}/complete")
async def api_complete_session(appointment_id: int):
    """Mark appointment complete then run full summarization pipeline."""
    from agents.session_agent import mark_appointment_complete
    from agents.summary_agent import summarize_appointment

    mark_result = mark_appointment_complete(appointment_id)
    if mark_result.get("error"):
        return JSONResponse(mark_result, status_code=404)

    summary_result = summarize_appointment(appointment_id)
    return JSONResponse({
        "status":  "completed",
        "summary": summary_result,
    })


# ─── Entry Point ─────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    import os
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))