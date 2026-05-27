from __future__ import annotations

import hashlib
import json
import os
import random
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Tuple

import requests
from fastapi import APIRouter, HTTPException, Header
from jose import JWTError, jwt
from pydantic import BaseModel, Field

try:
    from .auth import JWT_ALGORITHM, JWT_SECRET, get_db
except ImportError:
    from auth import JWT_ALGORITHM, JWT_SECRET, get_db

router = APIRouter(prefix="/streak", tags=["streak"])

PRIMARY_SUBJECTS = ("Physics", "Chemistry", "Biology")

SUBJECT_UNITS: Dict[str, List[str]] = {
    "Physics": [
        "Physics and Measurement",
        "Kinematics",
        "Laws of Motion",
        "Work, Energy and Power",
        "Rotational Motion",
        "Gravitation",
        "Properties of Solids and Liquids",
        "Thermodynamics",
        "Kinetic Theory of Gases",
        "Oscillations and Waves",
        "Electrostatics",
        "Current Electricity",
        "Magnetic Effects of Current and Magnetism",
        "Electromagnetic Induction and Alternating Currents",
        "Electromagnetic Waves",
        "Optics",
        "Dual Nature of Matter and Radiation",
        "Atoms and Nuclei",
        "Electronic Devices",
        "Experimental Skills",
    ],
    "Chemistry": [
        "Some Basic Concepts in Chemistry",
        "Atomic Structure",
        "Chemical Bonding and Molecular Structure",
        "Chemical Thermodynamics",
        "Solutions",
        "Equilibrium",
        "Redox Reactions and Electrochemistry",
        "Chemical Kinetics",
        "Classification of Elements and Periodicity in Properties",
        "P-Block Elements",
        "d- and f-Block Elements",
        "Co-ordination Compounds",
        "Purification and Characterisation of Organic Compounds",
        "Some Basic Principles of Organic Chemistry",
        "Hydrocarbons",
        "Organic Compounds Containing Halogens",
        "Organic Compounds Containing Oxygen",
        "Organic Compounds Containing Nitrogen",
        "Biomolecules",
        "Principles Related to Practical Chemistry",
    ],
    "Biology": [
        "Diversity in Living World",
        "Structural Organisation in Animals and Plants",
        "Cell Structure and Function",
        "Plant Physiology",
        "Human Physiology",
        "Reproduction",
        "Genetics and Evolution",
        "Biology and Human Welfare",
        "Biotechnology and Its Applications",
        "Ecology and Environment",
    ],
}


class DailyStreakSubmitRequest(BaseModel):
    answers: List[Optional[int]] = Field(default_factory=list)


def _today() -> date:
    return date.today()


def _clean(value: object) -> str:
    return str(value or "").replace("\u00a0", " ").strip()


def _question_hash(subject: str, unit: str, question: str, options: List[str]) -> str:
    fingerprint = "|".join(
        [subject.strip().lower(), unit.strip().lower(), question.strip().lower(), *[opt.strip().lower() for opt in options]]
    )
    return hashlib.sha1(fingerprint.encode("utf-8")).hexdigest()[:16]


def _answer_index_from_value(value: object) -> int:
    if isinstance(value, int):
        return max(0, min(3, value))
    text = _clean(value).upper()
    if text in {"A", "1"}:
        return 0
    if text in {"B", "2"}:
        return 1
    if text in {"C", "3"}:
        return 2
    if text in {"D", "4"}:
        return 3
    try:
        return max(0, min(3, int(text)))
    except Exception:
        return 0


def _mistral_api_key() -> str:
    return os.environ.get("MISTRAL_API_KEY", "").strip()


def _call_mistral_generate(api_key: str, prompt: str) -> str:
    if not api_key:
        raise RuntimeError("Missing MISTRAL_API_KEY")

    base_url = os.environ.get("MISTRAL_API_URL", "https://api.mistral.ai/v1/chat/completions")
    model_name = os.environ.get("MISTRAL_MODEL", "mistral-small-latest")
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    body = {
        "model": model_name,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.25,
        "max_tokens": 900,
    }
    timeout_secs = int(os.environ.get("MISTRAL_TIMEOUT", "10"))
    response = requests.post(base_url, headers=headers, json=body, timeout=timeout_secs)
    if response.status_code != 200:
        raise RuntimeError(f"Mistral API failed: {response.status_code} {response.text[:200]}")
    data = response.json()
    if isinstance(data, dict) and isinstance(data.get("choices"), list) and data["choices"]:
        choice = data["choices"][0]
        if isinstance(choice, dict):
            message = choice.get("message")
            if isinstance(message, dict):
                content = message.get("content")
                if isinstance(content, str) and content.strip():
                    return content.strip()
            text = choice.get("text") or choice.get("output")
            if isinstance(text, str) and text.strip():
                return text.strip()
    if isinstance(data, dict):
        for key in ("text", "response", "generated_text", "output"):
            value = data.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return response.text.strip()


def _strip_code_fences(raw: str) -> str:
    text = raw.strip()
    if text.startswith("```"):
        text = text.strip("`")
    return text.strip()


def _parse_question(raw: str, subject: str, unit: str) -> Dict:
    text = _strip_code_fences(raw)
    if text.startswith("[") and text.endswith("]"):
        data = json.loads(text)
        if isinstance(data, list) and data:
            data = data[0]
    else:
        start = text.find("{")
        end = text.rfind("}")
        if start >= 0 and end > start:
            data = json.loads(text[start : end + 1])
        else:
            data = json.loads(text)

    if not isinstance(data, dict):
        raise ValueError("Invalid question payload")

    options = data.get("options", [])
    if not isinstance(options, list):
        raise ValueError("Question options must be a list")

    cleaned_options = [_clean(option) for option in options[:4] if _clean(option)]
    if len(cleaned_options) != 4:
        raise ValueError("Question must include exactly 4 options")

    question = _clean(data.get("question", ""))
    if not question:
        raise ValueError("Missing question text")

    answer_index = _answer_index_from_value(data.get("answer_index", data.get("correct_answer", 0)))
    explanation = _clean(data.get("explanation", ""))
    concept = _clean(data.get("concept", data.get("topic", unit))) or unit

    return {
        "subject": subject,
        "unit": _clean(data.get("unit", unit)) or unit,
        "question": question,
        "options": cleaned_options,
        "answer_index": answer_index,
        "explanation": explanation,
        "concept": concept,
    }


def _fallback_question(subject: str, unit: str, rng: random.Random) -> Dict:
    prompt = f"Which NEET concept is most closely associated with {unit}?"
    subject_specific = {
        "Physics": [
            "The study of motion, forces, and energy",
            "The study of living cells",
            "The study of acids and bases",
            "The study of plant hormones",
        ],
        "Chemistry": [
            "The arrangement of electrons in atoms",
            "The movement of planets",
            "The effect of gravity on satellites",
            "The role of muscles in locomotion",
        ],
        "Biology": [
            "The study of heredity and variation",
            "The properties of electromagnetic waves",
            "The motion of charged particles",
            "The behavior of gases",
        ],
    }
    choices = list(subject_specific.get(subject, subject_specific["Physics"]))
    rng.shuffle(choices)
    options = [f"Core idea of {unit}", *choices[:3]]
    return {
        "subject": subject,
        "unit": unit,
        "question": prompt,
        "options": options,
        "answer_index": 0,
        "explanation": f"A fallback question for {unit} when the AI response is unavailable.",
        "concept": unit,
    }


def _selected_unit(subject: str, user_id: int, challenge_date: date) -> str:
    units = SUBJECT_UNITS[subject]
    seed = f"{user_id}:{challenge_date.isoformat()}:{subject}"
    digest = hashlib.sha1(seed.encode("utf-8")).hexdigest()
    index = int(digest[:8], 16) % len(units)
    return units[index]


def _generate_question(subject: str, unit: str, user_id: int, challenge_date: date) -> Dict:
    rng = random.Random(f"{user_id}:{challenge_date.isoformat()}:{subject}:{unit}")
    api_key = _mistral_api_key()
    if api_key:
        prompt = (
            f"Generate exactly one NEET level MCQ for {subject} from the unit '{unit}'.\n"
            "Return valid JSON only with keys: subject, unit, question, options, answer_index, explanation.\n"
            "options must be an array of exactly 4 strings. answer_index must be 0, 1, 2, or 3.\n"
            "Keep the question crisp, accurate, and suitable for daily practice.\n"
            "Do not add markdown, numbering, or any extra text."
        )
        try:
            raw = _call_mistral_generate(api_key, prompt)
            return _parse_question(raw, subject, unit)
        except Exception:
            pass
    return _fallback_question(subject, unit, rng)


def _get_user_from_token(authorization: Optional[str]) -> Dict[str, int]:
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
    return {"id": int(user_id)}


def _ensure_tables(cursor) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS daily_streak_state (
            user_id INT PRIMARY KEY,
            current_streak INT NOT NULL DEFAULT 0,
            best_streak INT NOT NULL DEFAULT 0,
            last_completed_date DATE NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS daily_streak_challenges (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            challenge_date DATE NOT NULL,
            questions_json LONGTEXT NOT NULL,
            submitted TINYINT(1) NOT NULL DEFAULT 0,
            score INT NOT NULL DEFAULT 0,
            answers_json LONGTEXT NULL,
            submitted_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_daily_streak (user_id, challenge_date),
            KEY idx_daily_streak_user_date (user_id, challenge_date)
        )
        """
    )


def _load_or_create_state(cursor, user_id: int) -> Dict:
    cursor.execute(
        "SELECT user_id, current_streak, best_streak, last_completed_date FROM daily_streak_state WHERE user_id = %s",
        (user_id,),
    )
    row = cursor.fetchone()
    if not row:
        cursor.execute(
            "INSERT INTO daily_streak_state (user_id, current_streak, best_streak, last_completed_date) VALUES (%s, 0, 0, NULL)",
            (user_id,),
        )
        return {"user_id": user_id, "current_streak": 0, "best_streak": 0, "last_completed_date": None}
    return row


def _challenge_units(user_id: int, challenge_date: date) -> List[Tuple[str, str]]:
    return [(subject, _selected_unit(subject, user_id, challenge_date)) for subject in PRIMARY_SUBJECTS]


def _as_date(value: object) -> Optional[date]:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str) and value:
        try:
            return date.fromisoformat(value)
        except ValueError:
            return None
    return None


def _normalize_streak_state(cursor, user_id: int, state: Dict, challenge_date: date) -> Dict:
    last_completed = _as_date(state.get("last_completed_date"))
    current_streak = int(state.get("current_streak", 0) or 0)
    if last_completed is None or last_completed < challenge_date - timedelta(days=1):
        if current_streak != 0:
            cursor.execute(
                "UPDATE daily_streak_state SET current_streak = 0 WHERE user_id = %s",
                (user_id,),
            )
        state["current_streak"] = 0
    return state


def _load_or_create_challenge(cursor, user_id: int, challenge_date: date) -> Dict:
    cursor.execute(
        "SELECT * FROM daily_streak_challenges WHERE user_id = %s AND challenge_date = %s",
        (user_id, challenge_date),
    )
    row = cursor.fetchone()
    if row:
        row["questions"] = json.loads(row["questions_json"] or "[]")
        row["answers"] = json.loads(row["answers_json"] or "[]") if row.get("answers_json") else []
        return row

    questions = []
    for subject, unit in _challenge_units(user_id, challenge_date):
        item = _generate_question(subject, unit, user_id, challenge_date)
        item["hash"] = _question_hash(subject, unit, item["question"], item["options"])
        questions.append(item)

    payload = json.dumps(questions, ensure_ascii=True)
    cursor.execute(
        "INSERT INTO daily_streak_challenges (user_id, challenge_date, questions_json, submitted, score) VALUES (%s, %s, %s, 0, 0)",
        (user_id, challenge_date, payload),
    )
    return {
        "user_id": user_id,
        "challenge_date": challenge_date,
        "questions_json": payload,
        "submitted": 0,
        "score": 0,
        "answers_json": None,
        "questions": questions,
        "answers": [],
    }


def _serialize_questions(questions: List[Dict], reveal_answers: bool) -> List[Dict]:
    payload = []
    for question in questions:
        item = {
            "subject": question.get("subject", ""),
            "unit": question.get("unit", ""),
            "question": question.get("question", ""),
            "options": question.get("options", []),
            "hash": question.get("hash", ""),
        }
        if reveal_answers:
            item["answer_index"] = question.get("answer_index", 0)
            item["explanation"] = question.get("explanation", "")
        payload.append(item)
    return payload


def _challenge_payload(
    challenge: Dict,
    state: Dict,
    *,
    reveal_answers: bool,
    message: str,
    can_attempt: bool,
) -> Dict:
    questions = challenge.get("questions", [])
    submitted = bool(int(challenge.get("submitted", 0) or 0))
    return {
        "date": str(challenge.get("challenge_date", _today())),
        "streak_days": int(state.get("current_streak", 0) or 0),
        "best_streak": int(state.get("best_streak", 0) or 0),
        "submitted": submitted,
        "can_attempt": can_attempt,
        "completed": submitted and int(challenge.get("score", 0) or 0) == len(questions),
        "score": int(challenge.get("score", 0) or 0),
        "total_questions": len(questions),
        "message": message,
        "questions": _serialize_questions(questions, reveal_answers=reveal_answers),
    }


@router.get("/today")
def get_today_challenge(authorization: Optional[str] = Header(None)):
    current_user = _get_user_from_token(authorization)
    challenge_date = _today()
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        _ensure_tables(cursor)
        state = _load_or_create_state(cursor, current_user["id"])
        state = _normalize_streak_state(cursor, current_user["id"], state, challenge_date)
        challenge = _load_or_create_challenge(cursor, current_user["id"], challenge_date)
        db.commit()
        submitted = bool(int(challenge.get("submitted", 0) or 0))
        message = (
            "Today's streak is already locked in."
            if submitted
            else "Three questions, one chance, one flame to protect."
        )
        return _challenge_payload(
            challenge,
            state,
            reveal_answers=submitted,
            message=message,
            can_attempt=not submitted,
        )
    finally:
        cursor.close()
        db.close()


@router.post("/today/submit")
def submit_today_challenge(req: DailyStreakSubmitRequest, authorization: Optional[str] = Header(None)):
    current_user = _get_user_from_token(authorization)
    challenge_date = _today()
    answers = [value if value is None else int(value) for value in req.answers]

    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        _ensure_tables(cursor)
        state = _load_or_create_state(cursor, current_user["id"])
        challenge = _load_or_create_challenge(cursor, current_user["id"], challenge_date)
        if int(challenge.get("submitted", 0) or 0) == 1:
            raise HTTPException(status_code=409, detail="Today's challenge has already been submitted.")

        questions = challenge.get("questions", [])
        if len(answers) != len(questions) or any(value is None for value in answers):
            raise HTTPException(status_code=400, detail="Answer all three questions before submitting.")

        score = 0
        reviewed_questions = []
        for index, question in enumerate(questions):
            answer_index = _answer_index_from_value(question.get("answer_index", 0))
            selected = answers[index]
            is_correct = selected is not None and int(selected) == answer_index
            if is_correct:
                score += 1
            reviewed_questions.append(
                {
                    **question,
                    "your_answer_index": selected,
                    "answer_index": answer_index,
                    "is_correct": is_correct,
                }
            )

        current_streak = int(state.get("current_streak", 0) or 0)
        best_streak = int(state.get("best_streak", 0) or 0)
        last_completed = state.get("last_completed_date")
        if isinstance(last_completed, datetime):
            last_completed = last_completed.date()
        yesterday = challenge_date - timedelta(days=1)
        if last_completed == yesterday:
            current_streak += 1
        else:
            current_streak = 1
        best_streak = max(best_streak, current_streak)
        state["last_completed_date"] = challenge_date

        cursor.execute(
            "UPDATE daily_streak_state SET current_streak = %s, best_streak = %s, last_completed_date = %s WHERE user_id = %s",
            (current_streak, best_streak, state.get("last_completed_date"), current_user["id"]),
        )
        cursor.execute(
            """
            UPDATE daily_streak_challenges
            SET submitted = 1, score = %s, answers_json = %s, submitted_at = NOW()
            WHERE user_id = %s AND challenge_date = %s
            """,
            (score, json.dumps(answers, ensure_ascii=True), current_user["id"], challenge_date),
        )
        db.commit()

        challenge["submitted"] = 1
        challenge["score"] = score
        challenge["answers"] = answers
        challenge["questions"] = reviewed_questions

        message = (
            f"Challenge complete. Your streak is now {current_streak}."
            if score == len(questions)
            else f"Challenge complete. You scored {score}/{len(questions)}, and your streak is now {current_streak}."
        )
        return _challenge_payload(
            challenge,
            {"current_streak": current_streak, "best_streak": best_streak},
            reveal_answers=True,
            message=message,
            can_attempt=False,
        )
    finally:
        cursor.close()
        db.close()


