import os
import bcrypt
import base64
import mysql.connector
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from jose import jwt
from datetime import datetime, timedelta

router = APIRouter()

JWT_SECRET = os.environ.get("JWT_SECRET", "neet_secret")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 24


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


def get_db():
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
        token = create_token(user_id, req.email.lower())
        return {"token": token, "name": req.name.strip(), "email": req.email.lower(), "photo": None}
    finally:
        cursor.close()
        db.close()


@router.post("/login")
def login(req: LoginRequest):
    if not req.email.strip() or not req.password.strip():
        raise HTTPException(status_code=400, detail="Email and password are required.")

    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM users WHERE email = %s", (req.email.lower(),))
        user = cursor.fetchone()
        if not user or not verify_password(req.password, user["password"]):
            raise HTTPException(status_code=401, detail="Invalid email or password.")
        token = create_token(user["id"], user["email"])
        photo_b64 = base64.b64encode(user["photo"]).decode('utf-8') if user.get("photo") else None
        return {"token": token, "name": user["name"], "email": user["email"], "photo": photo_b64}
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
