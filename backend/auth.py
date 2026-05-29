import os
import bcrypt
import base64
import mysql.connector
import logging
import time
import secrets
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Header
from pydantic import BaseModel
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional
import requests

logger = logging.getLogger("auth")
logging.basicConfig(level=logging.INFO)
router = APIRouter()

JWT_SECRET = os.environ.get("JWT_SECRET", "neet_secret")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 24


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


from mysql.connector import pooling

try:
    db_pool = pooling.MySQLConnectionPool(
        pool_name="auth_db_pool",
        pool_size=10,
        host=os.environ.get("DB_HOST", "localhost"),
        port=int(os.environ.get("DB_PORT", 3306)),
        database=os.environ.get("DB_NAME", "neet_app"),
        user=os.environ.get("DB_USER", "root"),
        password=os.environ.get("DB_PASSWORD", ""),
    )
except Exception:
    db_pool = None


def get_db():
    if db_pool:
        return db_pool.get_connection()
    return mysql.connector.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=int(os.environ.get("DB_PORT", 3306)),
        database=os.environ.get("DB_NAME", "neet_app"),
        user=os.environ.get("DB_USER", "root"),
        password=os.environ.get("DB_PASSWORD", ""),
    )


def create_token(user_id: int, email: str) -> str:
    payload = {
        "sub": str(user_id),
        "email": email,
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRE_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = None
    current_password: Optional[str] = None
    new_password: Optional[str] = None


class GoogleLoginRequest(BaseModel):
    token: str


def _serialize_user(user: dict, token: Optional[str] = None) -> dict:
    photo_b64 = base64.b64encode(user["photo"]).decode('utf-8') if user.get("photo") else None
    return {
        "token": token or create_token(user["id"], user["email"]),
        "name": user["name"],
        "email": user["email"],
        "photo": photo_b64,
    }


def _get_user_from_token(authorization: Optional[str]) -> dict:
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header is required.")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid authorization header.")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload.")
    return {"id": int(user_id), "email": payload.get("email")}


def _fetch_google_profile(token: str) -> dict:
    profile_endpoints = [
        "https://www.googleapis.com/oauth2/v2/userinfo",
        "https://www.googleapis.com/oauth2/v3/userinfo",
    ]
    last_error = None

    for endpoint in profile_endpoints:
        try:
            response = requests.get(
                endpoint,
                headers={"Authorization": f"Bearer {token}"},
                timeout=20,
            )
            if response.status_code == 200:
                data = response.json()
                email = (data.get("email") or "").strip().lower()
                if not email:
                    raise HTTPException(status_code=401, detail="Google sign-in did not return an email.")
                return {
                    "email": email,
                    "name": (data.get("name") or data.get("given_name") or email).strip(),
                    "photo": data.get("picture"),
                }
            last_error = response.text
        except requests.RequestException as exc:
            last_error = str(exc)

    tokeninfo_url = f"https://oauth2.googleapis.com/tokeninfo?id_token={token}"
    try:
        response = requests.get(tokeninfo_url, timeout=20)
        if response.status_code == 200:
            data = response.json()
            email = (data.get("email") or "").strip().lower()
            if not email:
                raise HTTPException(status_code=401, detail="Google sign-in did not return an email.")
            return {
                "email": email,
                "name": (data.get("name") or data.get("given_name") or email).strip(),
                "photo": data.get("picture"),
            }
        last_error = response.text
    except requests.RequestException as exc:
        last_error = str(exc)

    raise HTTPException(status_code=401, detail=f"Google sign-in verification failed. {last_error or ''}".strip())


@router.post("/register")
def register(req: RegisterRequest):
    if not req.name.strip() or not req.email.strip() or not req.password.strip():
        raise HTTPException(status_code=400, detail="All fields are required.")
    if len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters.")

    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id FROM users WHERE email = %s", (req.email.lower(),))
        if cursor.fetchone():
            raise HTTPException(status_code=409, detail="Email already registered.")
        hashed = hash_password(req.password)
        cursor.execute(
            "INSERT INTO users (name, email, password) VALUES (%s, %s, %s)",
            (req.name.strip(), req.email.lower().strip(), hashed),
        )
        db.commit()
        user_id = cursor.lastrowid
        user = {
            "id": user_id,
            "email": req.email.lower().strip(),
            "name": req.name.strip(),
            "photo": None,
        }
        token = create_token(user_id, user["email"])
        return _serialize_user(user, token=token)
    finally:
        cursor.close()
        db.close()


@router.post("/login")
def login(req: LoginRequest):
    t0 = time.time()
    logger.info(f"Login request received for email: {req.email}")
    if not req.email.strip() or not req.password.strip():
        raise HTTPException(status_code=400, detail="Email and password are required.")

    t_db_start = time.time()
    db = get_db()
    t_db_conn = time.time()
    logger.info(f"Database connection established in {t_db_conn - t_db_start:.4f}s")

    cursor = db.cursor(dictionary=True)
    try:
        t_query_start = time.time()
        cursor.execute("SELECT * FROM users WHERE email = %s", (req.email.lower(),))
        user = cursor.fetchone()
        t_query_end = time.time()
        logger.info(f"User query executed in {t_query_end - t_query_start:.4f}s")

        if not user:
            logger.warning(f"User not found for email: {req.email}")
            raise HTTPException(status_code=401, detail="Invalid email or password.")

        t_verify_start = time.time()
        pw_ok = verify_password(req.password, user["password"])
        t_verify_end = time.time()
        logger.info(f"Password verification took {t_verify_end - t_verify_start:.4f}s")

        if not pw_ok:
            logger.warning(f"Invalid password for email: {req.email}")
            raise HTTPException(status_code=401, detail="Invalid email or password.")

        t_token_start = time.time()
        token = create_token(user["id"], user["email"])
        t_token_end = time.time()
        logger.info(f"Token generation took {t_token_end - t_token_start:.4f}s")

        t_serialize_start = time.time()
        serialized = _serialize_user(user, token=token)
        t_serialize_end = time.time()
        logger.info(f"User serialization took {t_serialize_end - t_serialize_start:.4f}s")

        logger.info(f"Login completed successfully in {time.time() - t0:.4f}s")
        return serialized
    finally:
        cursor.close()
        db.close()


@router.post("/login/google")
def login_google(req: GoogleLoginRequest):
    if not req.token.strip():
        raise HTTPException(status_code=400, detail="Google token is required.")

    profile = _fetch_google_profile(req.token.strip())

    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM users WHERE email = %s", (profile["email"],))
        user = cursor.fetchone()

        if user:
            updates = []
            params = []
            if profile["name"] and profile["name"] != user["name"]:
                updates.append("name = %s")
                params.append(profile["name"])
            if profile.get("photo"):
                photo_resp = requests.get(profile["photo"], timeout=20)
                if photo_resp.status_code == 200 and photo_resp.content:
                    updates.append("photo = %s")
                    params.append(photo_resp.content)
            if updates:
                params.append(user["id"])
                cursor.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = %s", tuple(params))
                db.commit()

            cursor.execute("SELECT * FROM users WHERE id = %s", (user["id"],))
            refreshed = cursor.fetchone()
            return _serialize_user(refreshed)

        photo_bytes = None
        if profile.get("photo"):
            try:
                photo_resp = requests.get(profile["photo"], timeout=20)
                if photo_resp.status_code == 200 and photo_resp.content:
                    photo_bytes = photo_resp.content
            except requests.RequestException:
                photo_bytes = None

        temp_password = hash_password(secrets.token_urlsafe(24))
        cursor.execute(
            "INSERT INTO users (name, email, password, photo) VALUES (%s, %s, %s, %s)",
            (profile["name"], profile["email"], temp_password, photo_bytes),
        )
        db.commit()
        user_id = cursor.lastrowid
        user = {
            "id": user_id,
            "email": profile["email"],
            "name": profile["name"],
            "photo": photo_bytes,
        }
        return _serialize_user(user)
    finally:
        cursor.close()
        db.close()


@router.post("/profile")
def update_profile(req: UpdateProfileRequest, authorization: Optional[str] = Header(None)):
    current_user = _get_user_from_token(authorization)
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM users WHERE id = %s", (current_user["id"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found.")

        updates = []
        params = []

        if req.name is not None:
            new_name = req.name.strip()
            if not new_name:
                raise HTTPException(status_code=400, detail="Display name cannot be empty.")
            if new_name != user["name"]:
                updates.append("name = %s")
                params.append(new_name)

        if req.current_password is not None or req.new_password is not None:
            if not req.current_password or not req.new_password:
                raise HTTPException(status_code=400, detail="Current password and new password are required.")
            if not verify_password(req.current_password, user["password"]):
                raise HTTPException(status_code=401, detail="Current password is incorrect.")
            if len(req.new_password) < 6:
                raise HTTPException(status_code=400, detail="Password must be at least 6 characters.")
            updates.append("password = %s")
            params.append(hash_password(req.new_password))

        if not updates:
            raise HTTPException(status_code=400, detail="No profile changes provided.")

        params.append(user["id"])
        cursor.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = %s", tuple(params))
        db.commit()

        cursor.execute("SELECT * FROM users WHERE id = %s", (user["id"],))
        updated_user = cursor.fetchone()
        if not updated_user:
            raise HTTPException(status_code=404, detail="User not found.")

        token = create_token(updated_user["id"], updated_user["email"])
        return _serialize_user(updated_user, token=token)
    finally:
        cursor.close()
        db.close()


@router.post("/upload-photo")
async def upload_photo(email: str = Form(...), photo: UploadFile = File(...)):
    data = await photo.read()
    if len(data) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Photo too large. Max 5MB.")
    db = get_db()
    cursor = db.cursor()
    try:
        cursor.execute("UPDATE users SET photo = %s WHERE email = %s", (data, email.lower()))
        db.commit()
        photo_b64 = base64.b64encode(data).decode('utf-8')
        return {"photo": photo_b64}
    finally:
        cursor.close()
        db.close()
