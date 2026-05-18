from __future__ import annotations

import hashlib
import json
import os
import random
import re
import uuid
from collections import deque
from dataclasses import dataclass
from datetime import datetime
from functools import lru_cache
from pathlib import Path
from threading import Lock, Thread
from typing import Dict, List, Optional

import requests
from fastapi import APIRouter, HTTPException, Header
from jose import JWTError, jwt
from pydantic import BaseModel, Field

try:
    from .auth import JWT_ALGORITHM, JWT_SECRET, get_db
    from .pageindex import get_page_index
except ImportError:
    from auth import JWT_ALGORITHM, JWT_SECRET, get_db
    from pageindex import get_page_index

router = APIRouter(prefix="/mock-test", tags=["mock-test"])

BASE_DIR = Path(__file__).parent
DOCS_DIR = BASE_DIR / "docs"
TOTAL_QUESTIONS = 180
TOTAL_MARKS = 720
DURATION_SECONDS = 3 * 60 * 60
MOCK_TEST_ATTEMPTS_ALLOWED = 5
SUBJECT_QUOTAS = {"Physics": 45, "Chemistry": 45, "Biology": 90}
UNIT_QUIZ_COUNT = 10
UNIT_QUIZ_DURATION = 10 * 60
UNIT_QUIZ_VARIANTS = 5
VALID_DIFFICULTIES = {"Easy", "Medium", "Hard"}
VALID_QUESTION_TYPES = {
    "MCQ",
    "Assertion & Reason",
    "Match the Following",
    "Statement-based",
    "Numerical",
    "Diagram-based",
    "HOTS",
}

MOCK_TEST_CACHE_TARGET = 5


@dataclass
class MockTestCacheEntry:
    session_id: str
    questions: List[Dict]


_mock_test_cache_lock = Lock()
_mock_test_cache: Dict[int, deque[MockTestCacheEntry]] = {}
_mock_test_bg_threads: Dict[int, Thread] = {}


@lru_cache(maxsize=1)
def _fixed_set_paths() -> Dict[int, Dict[str, Path]]:
    mapping: Dict[int, Dict[str, Path]] = {}
    for set_id in range(1, 7):
        paper = DOCS_DIR / f"set{set_id}.txt"
        alt_paper = DOCS_DIR / f"mocktest_set{set_id}.txt"
        answer = DOCS_DIR / f"set{set_id}_answers.txt"
        # Accept alternate file naming (some ingested PDFs use `mocktest_set{n}.txt`).
        if not paper.exists() and alt_paper.exists():
            paper = alt_paper
        if paper.exists() and answer.exists():
            mapping[set_id] = {"paper": paper, "answer": answer}
    return mapping


def _parse_fixed_set_answers(answer_text: str) -> List[int]:
    answers: List[int] = []
    for match in re.finditer(r"(?m)^\s*A\.\s*([1-4 ]+)\s*$", answer_text):
        row = match.group(1)
        for token in row.split():
            if token in {"1", "2", "3", "4"}:
                answers.append(int(token) - 1)
    return answers


def _subject_for_fixed_question(index: int) -> str:
    if index <= 50:
        return "Physics"
    if index <= 100:
        return "Chemistry"
    return "Biology"


def _strip_devanagari_lines(text: str) -> str:
    """Remove Devanagari fragments while keeping the English parts of each line."""
    devanagari = re.compile(r'[\u0900-\u097F]')
    kept = []
    for line in text.splitlines():
        cleaned = devanagari.sub(' ', line).replace('\x00', ' ')
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()
        if cleaned:
            kept.append(cleaned)
    return '\n'.join(kept)


def _is_noise_line(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return False

    lowered = stripped.lower()
    if lowered.startswith('page ') and re.search(r'page\s+\d+/\d+', lowered):
        return True
    if 'space for rough work' in lowered:
        return True
    if 'answer key' in lowered or 'hint - sheet' in lowered or 'hint – sheet' in lowered:
        return True
    if 'major test series' in lowered or 'test booklet code' in lowered:
        return True
    if lowered.startswith('english /') or lowered.endswith(' english /'):
        return True
    if lowered.startswith('target:') or lowered.startswith('target :'):
        return True
    if lowered.startswith('test type:') or lowered.startswith('test type :'):
        return True
    if lowered.startswith('test pattern:') or lowered.startswith('test pattern :'):
        return True
    if lowered.startswith('subject :'):
        return True
    if re.fullmatch(r'section-[a-z]', lowered):
        return True
    return False


def _clean_fixed_set_text(text: str) -> str:
    cleaned_lines: List[str] = []
    for line in _strip_devanagari_lines(text).replace('\r\n', '\n').replace('\r', '\n').splitlines():
        if _is_noise_line(line):
            continue
        cleaned_lines.append(line.rstrip())
    return '\n'.join(cleaned_lines)


def _looks_like_fixed_question(question_text: str, options: List[str]) -> bool:
    combined = ' '.join([question_text, *options])
    if len(question_text.split()) < 4:
        return False
    ascii_letters = len(re.findall(r'[A-Za-z]', combined))
    devanagari = len(re.findall(r'[\u0900-\u097F]', combined))
    if ascii_letters < 12:
        return False
    if devanagari and devanagari > ascii_letters:
        return False
    if re.search(r'(?i)\b(answer key|hint|space for rough work|major test series)\b', combined):
        return False
    return True


def _parse_fixed_set_questions(paper_text: str, answers: List[int], set_id: int) -> List[Dict]:
    text = _clean_fixed_set_text(paper_text)
    starts = list(re.finditer(r"(?m)^\s*(\d{1,3})\.\s+", text))
    question_starts = [(int(m.group(1)), m.start()) for m in starts if int(m.group(1)) >= 1]
    question_starts.sort(key=lambda item: item[1])

    questions: List[Dict] = []
    seen_numbers: set[int] = set()
    seen_texts: set[str] = set()
    for index, (number, start) in enumerate(question_starts):
        if number in seen_numbers:
            continue
        seen_numbers.add(number)
        end = question_starts[index + 1][1] if index + 1 < len(question_starts) else len(text)
        block = text[start:end].strip()
        if not block:
            continue
        option_matches = list(re.finditer(r"(?ms)^\s*\((\d)\)\s*(.*?)(?=^\s*\(\d\)\s*|\Z)", block))
        options = [re.sub(r"\s+", " ", m.group(2)).strip() for m in option_matches[:4]]
        if len(options) < 4:
            alt_options = re.findall(r"\((\d)\)\s*([^\(]+?)(?=\s*\(\d\)\s*|$)", block, flags=re.S)
            options = [re.sub(r"\s+", " ", opt).strip() for _, opt in alt_options[:4]]
        question_text = block
        if option_matches:
            question_text = block[:option_matches[0].start()].strip()
        question_text = re.sub(r"^\s*\d{1,3}\.\s*", "", question_text).strip()
        question_text = re.sub(r"\s+", " ", question_text)

        if len(options) != 4 or not _looks_like_fixed_question(question_text, options):
            continue

        norm_q = question_text.strip().lower()
        if norm_q in seen_texts:
            continue
        seen_texts.add(norm_q)

        try:
            answer_index = int(answers[number - 1]) if 0 <= number - 1 < len(answers) else 0
        except Exception:
            answer_index = 0

        questions.append({
            "subject": _subject_for_fixed_question(number),
            "unit": f"Set {set_id}",
            "chapter": f"Set {set_id}",
            "question_type": "MCQ",
            "difficulty": "Medium",
            "question": question_text,
            "options": options,
            "answer_index": answer_index,
            "correct_answer": _answer_letter_from_index(answer_index),
            "passage": "",
            "explanation": "",
            "concept": f"Set {set_id}",
            "topic": f"Set {set_id}",
            "concept_key": f"fixed_set_{set_id}",
            "hash": hashlib.sha1(f"set{set_id}:{number}:{question_text}".encode("utf-8")).hexdigest()[:16],
        })
    return questions


@lru_cache(maxsize=6)
def _load_fixed_set_bundle(set_id: int) -> Dict:
    paths = _fixed_set_paths().get(set_id)
    if not paths:
        raise HTTPException(status_code=404, detail=f"Mock test set {set_id} not found.")
    paper_text = paths["paper"].read_text(encoding="utf-8", errors="ignore")
    answer_text = paths["answer"].read_text(encoding="utf-8", errors="ignore")
    answers = _parse_fixed_set_answers(answer_text)
    questions = _parse_fixed_set_questions(paper_text, answers, set_id)
    if not questions:
        raise HTTPException(status_code=500, detail=f"Unable to parse mock test set {set_id}.")
    return {
        "set_id": set_id,
        "title": f"Mock Test Set {set_id}",
        "total_questions": len(questions),
        "total_marks": len(questions) * 4,
        "duration_seconds": DURATION_SECONDS,
        "questions": questions,
        "rules": [
            "+4 for each correct answer",
            "-1 for each wrong answer",
            "0 for unattempted questions",
            "Pause and resume are supported during the test",
        ],
    }


@router.post("/fixed-set/{set_id}")
def fixed_set_endpoint(set_id: int, authorization: Optional[str] = Header(None)) -> Dict:
    """Return a parsed fixed mock-test bundle for the given set id.

    Validates the bearer token and returns the bundle produced by
    `_load_fixed_set_bundle`. This endpoint uses POST to align with
    other mock-test routes that require authentication.
    """
    # Validate token (user must be signed in to open fixed sets)
    _user_id_from_token(authorization)
    return _load_fixed_set_bundle(set_id)


class MockTestGenerateRequest(BaseModel):
    session_id: Optional[str] = None
    count: int = TOTAL_QUESTIONS
    exclude_hashes: List[str] = Field(default_factory=list)


class MockTestSubmitRequest(BaseModel):
    session_id: str
    answers: List[Optional[int]] = Field(default_factory=list)
    marked: List[int] = Field(default_factory=list)


@dataclass(frozen=True)
class QuestionSource:
    source: str
    text: str
    subject: str
    unit: str
    hash: str


def _clean_text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _concept_key(subject: str, unit: str, concept: str) -> str:
    return _normalize(f"{subject}|{unit}|{concept}")


def _answer_index_from_value(value: object) -> int:
    if isinstance(value, int):
        return max(0, min(3, value))
    text = str(value or "").strip().upper()
    if text in {"A", "B", "C", "D"}:
        return ord(text) - ord("A")
    try:
        return max(0, min(3, int(text)))
    except Exception:
        return 0


def _answer_letter_from_index(index: object) -> str:
    try:
        value = int(index)
    except Exception:
        value = 0
    value = max(0, min(3, value))
    return chr(ord("A") + value)


def _question_options(item: Dict) -> List[str]:
    options = item.get("options", [])
    if isinstance(options, dict):
        ordered = [options.get(key, "") for key in ("A", "B", "C", "D")]
        return [_clean_text(option) for option in ordered]
    if isinstance(options, list):
        return [_clean_text(option) for option in options[:4]]
    return []


def _normalized_question_type(value: object) -> str:
    text = _clean_text(value)
    if not text:
        return "MCQ"
    if text.lower() == "hots/application-based":
        return "HOTS"
    if text in VALID_QUESTION_TYPES:
        return text
    return "MCQ"


def _normalized_difficulty(value: object) -> str:
    text = _clean_text(value).title()
    if text in VALID_DIFFICULTIES:
        return text
    return "Medium"


def _normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().lower()


def _question_hash(question: str, options: List[str]) -> str:
    payload = _normalize(question) + "|" + "|".join(_normalize(opt) for opt in options[:4])
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]


def _unit_keywords(unit: str) -> List[str]:
    return [token for token in re.findall(r"[a-zA-Z]{3,}", unit.lower()) if token not in {"and", "the", "for", "with", "from", "into", "unit", "chapter"}]


def _generic_unit_question(subject: str, unit: str, rng: random.Random, source_text: str = "", difficulty: str = "Medium", variant_index: int = 0) -> Dict:
    unit_label = _clean_text(unit) or subject
    unit_lower = unit_label.lower()
    keywords = _unit_keywords(unit_label)
    key = " ".join(keywords)

    if subject == "Physics":
        if any(term in unit_lower for term in ["work", "energy", "power"]):
            question = "Which quantity is the rate of doing work?"
            answer = "Power"
            options = ["Power", "Work", "Energy", "Momentum"]
            concept = "Power"
        elif any(term in unit_lower for term in ["kinematics", "motion"]):
            question = "The slope of a velocity-time graph gives:"
            answer = "Acceleration"
            options = ["Acceleration", "Displacement", "Speed", "Force"]
            concept = "Velocity-time graph"
        elif any(term in unit_lower for term in ["laws of motion", "force"]):
            question = "Newton's second law relates force to:"
            answer = "Rate of change of momentum"
            options = ["Rate of change of momentum", "Mass only", "Velocity only", "Time period"]
            concept = "Newton's second law"
        elif any(term in unit_lower for term in ["gravitation"]):
            question = "The acceleration due to gravity near the Earth's surface is approximately:"
            answer = "9.8 m/s²"
            options = ["9.8 m/s²", "1.6 m/s²", "3.0 m/s²", "15.0 m/s²"]
            concept = "Acceleration due to gravity"
        elif any(term in unit_lower for term in ["current electricity", "electricity"]):
            question = "The SI unit of electric resistance is:"
            answer = "Ohm"
            options = ["Ohm", "Volt", "Ampere", "Watt"]
            concept = "Resistance"
        elif any(term in unit_lower for term in ["electrostatics"]):
            question = "Like charges:"
            answer = "Repel each other"
            options = ["Repel each other", "Attract each other", "Always become neutral", "Have no force"]
            concept = "Electrostatic force"
        elif any(term in unit_lower for term in ["magnetic", "induction", "alternating"]):
            question = "The SI unit of magnetic flux density is:"
            answer = "Tesla"
            options = ["Tesla", "Weber", "Henry", "Farad"]
            concept = "Magnetic flux density"
        elif any(term in unit_lower for term in ["optics"]):
            question = "A convex lens can produce a real image when the object is placed:"
            answer = "Beyond the focal length"
            options = ["Beyond the focal length", "At the optical centre", "Between lens and focus only", "At infinity only"]
            concept = "Image formation by lens"
        elif any(term in unit_lower for term in ["atom", "nucleus"]):
            question = "The nucleus of an atom contains:"
            answer = "Protons and neutrons"
            options = ["Protons and neutrons", "Only electrons", "Only neutrons", "Only protons"]
            concept = "Atomic nucleus"
        elif any(term in unit_lower for term in ["waves", "oscillations", "oscillation"]):
            question = "Time period is the reciprocal of:"
            answer = "Frequency"
            options = ["Frequency", "Amplitude", "Wavelength", "Speed"]
            concept = "Periodic motion"
        else:
            bank = [
                ("Which physical quantity is measured in newton?", "Force", ["Force", "Work", "Power", "Energy"], "Force"),
                ("What is the SI unit of speed?", "m/s", ["m/s", "kg", "newton", "joule"], "Speed"),
                ("Which relation gives work done?", "Force x displacement", ["Force x displacement", "Mass x velocity", "Charge x time", "Pressure x area"], "Work"),
                ("Power is defined as: ", "Work per unit time", ["Work per unit time", "Force per unit mass", "Mass per unit volume", "Energy per unit charge"], "Power"),
                ("Momentum is the product of: ", "Mass and velocity", ["Mass and velocity", "Force and time", "Energy and time", "Pressure and area"], "Momentum"),
                ("Density is mass per: ", "Unit volume", ["Unit volume", "Unit time", "Unit charge", "Unit length"], "Density"),
            ]
            q, ans, opts, concept = bank[variant_index % len(bank)]
            question = q
            answer = ans
            options = opts
    elif subject == "Chemistry":
        if any(term in unit_lower for term in ["basic concepts", "mole"]):
            question = "One mole contains:"
            answer = "Avogadro number of particles"
            options = ["Avogadro number of particles", "1 gram of substance", "10 particles only", "6 atoms only"]
            concept = "Mole concept"
        elif any(term in unit_lower for term in ["atomic structure"]):
            question = "Atomic number of an element equals the number of:"
            answer = "Protons"
            options = ["Protons", "Neutrons", "Isotopes", "Molecules"]
            concept = "Atomic number"
        elif any(term in unit_lower for term in ["bonding", "molecular structure"]):
            question = "A covalent bond is formed by:"
            answer = "Sharing of electrons"
            options = ["Sharing of electrons", "Transfer of protons", "Loss of neutrons", "Release of heat only"]
            concept = "Covalent bonding"
        elif any(term in unit_lower for term in ["thermodynamics"]):
            question = "At constant pressure, heat change of a system is equal to its:"
            answer = "Enthalpy change"
            options = ["Enthalpy change", "Entropy only", "Atomic mass", "Mole fraction"]
            concept = "Thermodynamics"
        elif any(term in unit_lower for term in ["equilibrium"]):
            question = "At chemical equilibrium, the forward and reverse reaction rates are:"
            answer = "Equal"
            options = ["Equal", "Zero", "Infinite", "Always different"]
            concept = "Chemical equilibrium"
        elif any(term in unit_lower for term in ["solution", "solutions"]):
            question = "Molarity is defined as moles of solute per:"
            answer = "Litre of solution"
            options = ["Litre of solution", "Kilogram of solvent", "Mole of solvent", "Millilitre of gas"]
            concept = "Molarity"
        elif any(term in unit_lower for term in ["redox", "electrochemistry"]):
            question = "Oxidation involves:"
            answer = "Loss of electrons"
            options = ["Loss of electrons", "Gain of electrons", "Loss of protons", "Gain of neutrons"]
            concept = "Oxidation"
        elif any(term in unit_lower for term in ["kinetics"]):
            question = "Rate of a reaction generally increases when temperature:"
            answer = "Increases"
            options = ["Increases", "Decreases", "Becomes zero", "Has no effect"]
            concept = "Chemical kinetics"
        elif any(term in unit_lower for term in ["periodicity", "periodic"]):
            question = "Elements in the same group generally have the same:"
            answer = "Valence electron configuration"
            options = ["Valence electron configuration", "Atomic mass", "Nuclear charge only", "Number of isotopes"]
            concept = "Periodic properties"
        elif any(term in unit_lower for term in ["p-block"]):
            question = "Halogens belong to which group of the periodic table?"
            answer = "Group 17"
            options = ["Group 17", "Group 1", "Group 2", "Group 18"]
            concept = "P-block elements"
        elif any(term in unit_lower for term in ["coordination"]):
            question = "Ligands in coordination compounds donate:"
            answer = "Lone pair of electrons"
            options = ["Lone pair of electrons", "Neutrons", "Protons", "Metal ions only"]
            concept = "Coordination chemistry"
        elif any(term in unit_lower for term in ["hydrocarbon", "organic"]):
            question = "Alkanes contain only:"
            answer = "Single bonds"
            options = ["Single bonds", "Only triple bonds", "Only ionic bonds", "No carbon bonds"]
            concept = "Hydrocarbons"
        elif any(term in unit_lower for term in ["oxygen", "alcohol", "carbonyl"]):
            question = "Alcohols contain which functional group?"
            answer = "-OH"
            options = ["-OH", "-COOH", "-NH2", "-X"]
            concept = "Alcohol functional group"
        elif any(term in unit_lower for term in ["nitrogen", "amine"]):
            question = "Amines are derivatives of:"
            answer = "Ammonia"
            options = ["Ammonia", "Water", "Methane", "Hydrogen chloride"]
            concept = "Amines"
        elif any(term in unit_lower for term in ["biomolecule"]):
            question = "Glucose is a:"
            answer = "Carbohydrate"
            options = ["Carbohydrate", "Protein", "Lipid", "Nucleic acid"]
            concept = "Biomolecules"
        else:
            bank = [
                ("One mole contains: ", "Avogadro number of particles", ["Avogadro number of particles", "1 gram of substance", "10 particles only", "6 atoms only"], "Mole concept"),
                ("Atomic number equals the number of: ", "Protons", ["Protons", "Neutrons", "Isotopes", "Molecules"], "Atomic number"),
                ("A covalent bond is formed by: ", "Sharing of electrons", ["Sharing of electrons", "Transfer of protons", "Loss of neutrons", "Release of heat only"], "Covalent bond"),
                ("At equilibrium, forward and reverse reaction rates are: ", "Equal", ["Equal", "Zero", "Infinite", "Always different"], "Chemical equilibrium"),
                ("Oxidation involves: ", "Loss of electrons", ["Loss of electrons", "Gain of electrons", "Loss of protons", "Gain of neutrons"], "Oxidation"),
                ("Molarity is defined as moles of solute per: ", "Litre of solution", ["Litre of solution", "Kilogram of solvent", "Mole of solvent", "Millilitre of gas"], "Molarity"),
            ]
            q, ans, opts, concept = bank[variant_index % len(bank)]
            question = q
            answer = ans
            options = opts
    else:
        if any(term in unit_lower for term in ["diversity", "living world"]):
            question = "Binomial nomenclature consists of genus and:"
            answer = "Species"
            options = ["Species", "Family", "Order", "Phylum"]
            concept = "Binomial nomenclature"
        elif any(term in unit_lower for term in ["structural organisation", "cell"]):
            question = "The basic structural unit of living organisms is the:"
            answer = "Cell"
            options = ["Cell", "Tissue", "Organ", "System"]
            concept = "Cell as unit of life"
        elif any(term in unit_lower for term in ["plant physiology"]):
            question = "Xylem mainly transports:"
            answer = "Water and minerals"
            options = ["Water and minerals", "Food only", "Hormones only", "Oxygen only"]
            concept = "Xylem transport"
        elif any(term in unit_lower for term in ["human physiology"]):
            question = "Red blood cells mainly transport:"
            answer = "Oxygen"
            options = ["Oxygen", "Enzymes", "Glucose", "Urea"]
            concept = "Blood and transport"
        elif any(term in unit_lower for term in ["reproduction"]):
            question = "In humans, fertilization usually occurs in the:"
            answer = "Fallopian tube"
            options = ["Fallopian tube", "Uterus", "Vagina", "Ovary"]
            concept = "Human reproduction"
        elif any(term in unit_lower for term in ["genetics", "evolution"]):
            question = "DNA is the molecule that carries:"
            answer = "Genetic information"
            options = ["Genetic information", "Only water", "Only minerals", "Heat energy"]
            concept = "Genetic material"
        elif any(term in unit_lower for term in ["biotechnology"]):
            question = "PCR is used for:"
            answer = "Amplification of DNA"
            options = ["Amplification of DNA", "Protein digestion", "Cell division", "Photosynthesis"]
            concept = "PCR"
        elif any(term in unit_lower for term in ["ecology", "environment"]):
            question = "An ecosystem consists of biotic and:"
            answer = "Abiotic components"
            options = ["Abiotic components", "Only plants", "Only animals", "Only microbes"]
            concept = "Ecosystem"
        elif any(term in unit_lower for term in ["human welfare"]):
            question = "Antibiotics primarily act against:"
            answer = "Bacteria"
            options = ["Bacteria", "Viruses", "All fungi", "Plants"]
            concept = "Health and disease"
        else:
            bank = [
                ("The basic structural unit of living organisms is the: ", "Cell", ["Cell", "Tissue", "Organ", "System"], "Cell"),
                ("DNA carries: ", "Genetic information", ["Genetic information", "Only water", "Only minerals", "Heat energy"], "DNA"),
                ("Xylem mainly transports: ", "Water and minerals", ["Water and minerals", "Food only", "Hormones only", "Oxygen only"], "Xylem"),
                ("Red blood cells mainly transport: ", "Oxygen", ["Oxygen", "Enzymes", "Glucose", "Urea"], "RBC"),
                ("PCR is used for: ", "Amplification of DNA", ["Amplification of DNA", "Protein digestion", "Cell division", "Photosynthesis"], "PCR"),
                ("An ecosystem consists of biotic and: ", "Abiotic components", ["Abiotic components", "Only plants", "Only animals", "Only microbes"], "Ecosystem"),
            ]
            q, ans, opts, concept = bank[variant_index % len(bank)]
            question = q
            answer = ans
            options = opts

    if source_text and len(source_text) > 40:
        explanation = source_text[:260]
    else:
        explanation = f"This tests the core idea of {unit_label}."

    answer_index = options.index(answer) if answer in options else 0
    concept_key = _concept_key(subject, unit_label, concept)
    fingerprint = _question_hash(question, options)
    return {
        "subject": subject,
        "unit": unit_label,
        "chapter": unit_label,
        "question_type": "MCQ",
        "difficulty": _normalized_difficulty(difficulty),
        "question": question,
        "options": options[:4],
        "answer_index": answer_index,
        "correct_answer": _answer_letter_from_index(answer_index),
        "passage": "",
        "explanation": explanation,
        "concept": concept,
        "topic": unit_label,
        "concept_key": concept_key,
        "hash": fingerprint,
    }


def _load_text_docs() -> List[Dict[str, str]]:
    docs: List[Dict[str, str]] = []
    if not DOCS_DIR.exists():
        return docs
    for file_path in sorted(DOCS_DIR.glob("*.txt")):
        try:
            text = file_path.read_text(encoding="utf-8")
        except Exception:
            continue
        docs.append({"source": file_path.name, "text": text})
    return docs


@lru_cache(maxsize=1)
def _syllabus_units() -> Dict[str, List[str]]:
    units = {"Physics": [], "Chemistry": [], "Biology": []}
    syllabus_path = DOCS_DIR / "NEET_Syllabus.txt"
    if not syllabus_path.exists():
        return units

    current_subject = None
    try:
        for raw_line in syllabus_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line:
                continue
            upper = line.upper()
            if upper == "PHYSICS":
                current_subject = "Physics"
                continue
            if upper == "CHEMISTRY":
                current_subject = "Chemistry"
                continue
            if upper == "BIOLOGY":
                current_subject = "Biology"
                continue
            match = re.match(r"UNIT\s*\d+\s*:\s*(.+)", line, flags=re.I)
            if match and current_subject:
                title = match.group(1).strip()
                if title and title not in units[current_subject]:
                    units[current_subject].append(title)
    except Exception:
        return units
    return units


def _subject_from_text(text: str, source: str) -> str:
    lower = f"{source} {text}".lower()
    physics_hits = sum(term in lower for term in ["physics", "kinematics", "motion", "force", "current", "optics", "wave", "electric"])
    chemistry_hits = sum(term in lower for term in ["chemistry", "mole", "atom", "bond", "organic", "inorganic", "solution", "equilibrium"])
    biology_hits = sum(term in lower for term in ["biology", "cell", "plant", "animal", "gene", "genetics", "ecology", "human", "reproduction"])

    if physics_hits >= chemistry_hits and physics_hits >= biology_hits and physics_hits > 0:
        return "Physics"
    if chemistry_hits >= physics_hits and chemistry_hits >= biology_hits and chemistry_hits > 0:
        return "Chemistry"
    if biology_hits >= physics_hits and biology_hits >= chemistry_hits and biology_hits > 0:
        return "Biology"

    if "phy" in source.lower() or "physics" in source.lower():
        return "Physics"
    if "che" in source.lower() or "chem" in source.lower():
        return "Chemistry"
    return "Biology"


def _best_unit(subject: str, text: str) -> str:
    units = _syllabus_units().get(subject, [])
    if not units:
      return subject
    text_lower = text.lower()
    best_unit = subject
    best_score = 0
    for unit in units:
        tokens = [t for t in re.findall(r"[a-zA-Z]{4,}", unit.lower())]
        score = sum(1 for token in tokens if token in text_lower)
        if score > best_score:
            best_score = score
            best_unit = unit
    return best_unit


def _split_question_blocks(text: str) -> List[str]:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    blocks: List[str] = []
    current: List[str] = []
    for raw_line in normalized.splitlines():
        line = raw_line.strip()
        if not line:
            if current:
                current.append("")
            continue
        if re.match(r"^\d+\s*[\).]\s+", line) and current:
            blocks.append("\n".join(current).strip())
            current = [line]
            continue
        if not current and re.match(r"^\d+\s*[\).]\s+", line):
            current = [line]
        else:
            current.append(line)
    if current:
        blocks.append("\n".join(current).strip())
    return [block for block in blocks if len(block.split()) >= 8]


@lru_cache(maxsize=1)
def _question_sources() -> Dict[str, List[QuestionSource]]:
    grouped: Dict[str, List[QuestionSource]] = {"Physics": [], "Chemistry": [], "Biology": []}
    for doc in _load_text_docs():
        source = doc["source"]
        for block in _split_question_blocks(doc["text"]):
            subject = _subject_from_text(block, source)
            unit = _best_unit(subject, block)
            fingerprint = _question_hash(block[:240], [source, subject, unit])
            grouped[subject].append(QuestionSource(source=source, text=block, subject=subject, unit=unit, hash=fingerprint))
    return grouped


def _token_from_header(authorization: Optional[str]) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization token required.")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(status_code=401, detail="Bearer token required.")
    return token.strip()


def _user_id_from_token(authorization: Optional[str]) -> int:
    token = _token_from_header(authorization)
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload.get("sub", "0"))
    except (JWTError, TypeError, ValueError) as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token.") from exc
    if user_id <= 0:
        raise HTTPException(status_code=401, detail="Invalid token payload.")
    return user_id


def _get_db_cursor(dictionary: bool = True):
    db = get_db()
    cursor = db.cursor(dictionary=dictionary)
    return db, cursor


def _add_column_if_missing(cursor, table: str, column: str, ddl: str) -> None:
    try:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {ddl}")
    except Exception:
        pass


def _ensure_schema() -> None:
    db, cursor = _get_db_cursor(dictionary=False)
    try:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS mock_test_sessions (
                id VARCHAR(64) PRIMARY KEY,
                user_id INT NOT NULL,
                created_at DATETIME NOT NULL,
                submitted_at DATETIME NULL,
                status VARCHAR(20) NOT NULL,
                total_questions INT NOT NULL,
                total_marks INT NOT NULL,
                duration_seconds INT NOT NULL,
                question_payload LONGTEXT NOT NULL,
                answer_key LONGTEXT NOT NULL,
                submitted_answers LONGTEXT NULL,
                marked LONGTEXT NULL,
                score INT NULL,
                correct_count INT NULL,
                wrong_count INT NULL,
                unanswered_count INT NULL,
                accuracy DECIMAL(6,2) NULL,
                subject_stats LONGTEXT NULL,
                UNIQUE KEY uniq_mock_session (id),
                KEY idx_mock_test_user (user_id)
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS mock_test_question_history (
                id BIGINT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                session_id VARCHAR(64) NOT NULL,
                question_hash VARCHAR(64) NOT NULL,
                concept_key VARCHAR(255) NOT NULL DEFAULT '',
                subject VARCHAR(20) NOT NULL,
                unit VARCHAR(255) NOT NULL,
                created_at DATETIME NOT NULL,
                UNIQUE KEY uniq_user_question_hash (user_id, question_hash),
                KEY idx_mock_history_user (user_id)
            )
            """
        )
        db.commit()
        # Unit quiz sessions and history
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS unit_quiz_sessions (
                id VARCHAR(64) PRIMARY KEY,
                user_id INT NOT NULL,
                subject VARCHAR(50) NOT NULL,
                unit VARCHAR(255) NOT NULL,
                variant INT NOT NULL,
                created_at DATETIME NOT NULL,
                submitted_at DATETIME NULL,
                status VARCHAR(20) NOT NULL,
                total_questions INT NOT NULL,
                duration_seconds INT NOT NULL,
                question_payload LONGTEXT NOT NULL,
                answer_key LONGTEXT NOT NULL,
                submitted_answers LONGTEXT NULL,
                marked LONGTEXT NULL,
                score INT NULL,
                correct_count INT NULL,
                wrong_count INT NULL,
                unanswered_count INT NULL,
                accuracy DECIMAL(6,2) NULL,
                UNIQUE KEY uniq_unit_quiz_session (id),
                KEY idx_unit_quiz_user (user_id)
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS unit_quiz_question_history (
                id BIGINT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                session_id VARCHAR(64) NOT NULL,
                question_hash VARCHAR(64) NOT NULL,
                concept_key VARCHAR(255) NOT NULL DEFAULT '',
                subject VARCHAR(50) NOT NULL,
                unit VARCHAR(255) NOT NULL,
                created_at DATETIME NOT NULL,
                UNIQUE KEY uniq_unit_user_question_hash (user_id, question_hash),
                KEY idx_unit_history_user (user_id)
            )
            """
        )
        db.commit()
        # rotation pool for per-user per-unit questions
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS unit_quiz_rotation (
                id VARCHAR(64) PRIMARY KEY,
                user_id INT NOT NULL,
                subject VARCHAR(50) NOT NULL,
                unit VARCHAR(255) NOT NULL,
                question_hash VARCHAR(64) NOT NULL,
                concept_key VARCHAR(255) NOT NULL DEFAULT '',
                question_payload LONGTEXT NOT NULL,
                used TINYINT(1) NOT NULL DEFAULT 0,
                created_at DATETIME NOT NULL,
                used_at DATETIME NULL,
                UNIQUE KEY uniq_rotation_hash (user_id, subject, unit, question_hash),
                KEY idx_rotation_user (user_id)
            )
            """
        )
        db.commit()

        _add_column_if_missing(cursor, "mock_test_question_history", "concept_key", "VARCHAR(255) NOT NULL DEFAULT ''")
        _add_column_if_missing(cursor, "unit_quiz_question_history", "concept_key", "VARCHAR(255) NOT NULL DEFAULT ''")
        _add_column_if_missing(cursor, "unit_quiz_rotation", "concept_key", "VARCHAR(255) NOT NULL DEFAULT ''")
        db.commit()
    finally:
        cursor.close()
        db.close()


def _build_unit_coverage_questions(user_id: int, session_id: str, seed: str, excluded_hashes: List[str]) -> List[Dict]:
    """Generate at least one question for every syllabus unit present in docs."""
    coverage: List[Dict] = []
    history_hashes = _load_all_question_history(user_id)
    used_hashes = set(excluded_hashes) | set(history_hashes)
    rng = random.Random(seed)

    for subject in ("Physics", "Chemistry", "Biology"):
        units = list(_syllabus_units().get(subject, []))
        if not units:
            continue
        rng.shuffle(units)
        for unit in units:
            if len(coverage) >= TOTAL_QUESTIONS:
                break
            unit_questions = _generate_unit_questions(
                subject,
                unit,
                1,
                list(used_hashes),
                f"{seed}:{session_id}:{subject}:{unit}:coverage",
                history_concepts=_load_concept_history(user_id),
            )
            if not unit_questions:
                continue
            candidate = unit_questions[0]
            qhash = str(candidate.get("hash", "")).strip()
            if not qhash or qhash in used_hashes:
                continue
            coverage.append(candidate)
            used_hashes.add(qhash)

    return coverage


def _build_mock_test_questions(
    user_id: int,
    session_id: str,
    seed: str,
    excluded_hashes: List[str],
    history_hashes: set[str],
) -> List[Dict]:
    count = TOTAL_QUESTIONS
    quotas = SUBJECT_QUOTAS.copy()
    all_questions: List[Dict] = []

    coverage_questions = _build_unit_coverage_questions(user_id, session_id, seed, excluded_hashes)
    all_questions.extend(coverage_questions)

    for subject, quota in quotas.items():
        if len(all_questions) >= count:
            break
        subject_questions = _generate_subject_questions(subject, quota, excluded_hashes + list(history_hashes), seed)
        all_questions.extend(subject_questions)

    if len(all_questions) < count:
        all_questions = all_questions[:]
        additional_subjects = ["Physics", "Chemistry", "Biology"]
        rng = random.Random(seed)
        while len(all_questions) < count:
            subject = additional_subjects[len(all_questions) % len(additional_subjects)]
            subject_sources = _subject_sources(subject)
            if not subject_sources:
                break
            candidate = _fallback_question_from_source(rng.choice(subject_sources), rng)
            qhash = candidate["hash"]
            if not _question_is_unique(qhash, {item["hash"] for item in all_questions}, history_hashes, excluded_hashes):
                break
            all_questions.append(candidate)

    deduped: List[Dict] = []
    seen_hashes = set()
    for item in all_questions:
        qhash = str(item.get("hash", "")).strip()
        if not qhash or qhash in seen_hashes:
            continue
        seen_hashes.add(qhash)
        deduped.append(item)

    all_questions = deduped[:count]
    if len(all_questions) < count:
        raise HTTPException(status_code=500, detail="Unable to generate enough unique mock test questions.")

    return all_questions


def _prime_mock_test_cache(user_id: int, target_size: int = MOCK_TEST_CACHE_TARGET, use_fallback: bool = False) -> int:
    with _mock_test_cache_lock:
        cache = _mock_test_cache.setdefault(user_id, deque())
        while len(cache) < target_size:
            reserved_hashes = _load_user_history(user_id)
            for entry in cache:
                reserved_hashes.update(str(question.get("hash", "")).strip() for question in entry.questions)
            session_id = str(uuid.uuid4())
            seed = f"{user_id}:{session_id}:{datetime.utcnow().date().isoformat()}:{len(cache)}"
            if use_fallback:
                questions = _build_mock_test_fallback_questions(user_id, session_id, seed, list(reserved_hashes), reserved_hashes)
            else:
                questions = _build_mock_test_questions(user_id, session_id, seed, list(reserved_hashes), reserved_hashes)
            cache.append(MockTestCacheEntry(session_id=session_id, questions=questions))
        return len(cache)


def _build_mock_test_fallback_questions(
    user_id: int,
    session_id: str,
    seed: str,
    excluded_hashes: List[str],
    history_hashes: set[str],
) -> List[Dict]:
    """Fast fallback-only paper builder that avoids LLM calls.
    Uses the syllabus units and fallback generators to assemble a full paper quickly.
    """
    count = TOTAL_QUESTIONS
    quotas = SUBJECT_QUOTAS.copy()
    all_questions: List[Dict] = []
    rng = random.Random(seed)

    # Ensure at least one per unit (fallback)
    for subject in ("Physics", "Chemistry", "Biology"):
        units = list(_syllabus_units().get(subject, []))
        rng.shuffle(units)
        for unit in units:
            if len(all_questions) >= count:
                break
            candidate = _fallback_question_for_unit(subject, unit, rng, difficulty="Medium", variant_index=0)
            qhash = candidate.get("hash", "")
            if not qhash or qhash in history_hashes or qhash in set(excluded_hashes):
                continue
            all_questions.append(candidate)

    # Fill subject quotas using fallback
    for subject, quota in quotas.items():
        needed = quota
        idx = 0
        while needed > 0:
            unit_list = _syllabus_units().get(subject, []) or [subject]
            unit = unit_list[idx % len(unit_list)]
            candidate = _fallback_question_for_unit(subject, unit, rng, difficulty="Medium", variant_index=idx)
            idx += 1
            qhash = candidate.get("hash", "")
            if not qhash or qhash in history_hashes or qhash in set(excluded_hashes) or qhash in {q.get("hash", "") for q in all_questions}:
                continue
            all_questions.append(candidate)
            needed -= 1

    # Final pad if still short
    subjects = ["Physics", "Chemistry", "Biology"]
    idx = 0
    while len(all_questions) < count:
        subject = subjects[idx % len(subjects)]
        srcs = _subject_sources(subject)
        if not srcs:
            break
        candidate = _fallback_question_from_source(rng.choice(srcs), rng)
        idx += 1
        qhash = candidate.get("hash", "")
        if not qhash or qhash in history_hashes or qhash in set(excluded_hashes) or qhash in {q.get("hash", "") for q in all_questions}:
            continue
        all_questions.append(candidate)

    # Deduplicate and trim
    seen = set()
    deduped = []
    for it in all_questions:
        h = str(it.get("hash", "")).strip()
        if not h or h in seen:
            continue
        seen.add(h)
        deduped.append(it)
    all_questions = deduped[:count]
    if len(all_questions) < count:
        # fallback: repeat last items (shouldn't happen)
        while len(all_questions) < count:
            all_questions.append(all_questions[-1])
    return all_questions


def _pop_mock_test_cache(user_id: int) -> Optional[MockTestCacheEntry]:
    with _mock_test_cache_lock:
        cache = _mock_test_cache.setdefault(user_id, deque())
        if cache:
            return cache.popleft()
    return None


def _load_user_history(user_id: int) -> set[str]:
    db, cursor = _get_db_cursor()
    try:
        cursor.execute("SELECT question_hash FROM mock_test_question_history WHERE user_id = %s", (user_id,))
        rows = cursor.fetchall() or []
        return {str(row.get("question_hash", "")) for row in rows if str(row.get("question_hash", "")).strip()}
    finally:
        cursor.close()
        db.close()


def _count_mock_test_attempts(user_id: int) -> int:
    db, cursor = _get_db_cursor()
    try:
        cursor.execute("SELECT COUNT(1) as cnt FROM mock_test_sessions WHERE user_id = %s", (user_id,))
        row = cursor.fetchone() or {}
        return int(row.get("cnt", 0) or 0)
    finally:
        cursor.close()
        db.close()


def _load_concept_history(user_id: int) -> set[str]:
    db, cursor = _get_db_cursor()
    try:
        cursor.execute("SELECT concept_key FROM unit_quiz_question_history WHERE user_id = %s", (user_id,))
        rows = cursor.fetchall() or []
        return {str(row.get("concept_key", "")).strip() for row in rows if str(row.get("concept_key", "")).strip()}
    except Exception:
        return set()
    finally:
        cursor.close()
        db.close()


def _history_by_subject(user_id: int) -> Dict[str, set[str]]:
    db, cursor = _get_db_cursor()
    try:
        cursor.execute("SELECT question_hash, subject FROM mock_test_question_history WHERE user_id = %s", (user_id,))
        rows = cursor.fetchall() or []
        result = {"Physics": set(), "Chemistry": set(), "Biology": set()}
        for row in rows:
            subject = str(row.get("subject", "")).strip().title()
            qhash = str(row.get("question_hash", "")).strip()
            if subject in result and qhash:
                result[subject].add(qhash)
        return result
    finally:
        cursor.close()
        db.close()


def _question_is_unique(
    question_hash: str,
    used_hashes: set[str],
    history_hashes: set[str],
    excluded_hashes: List[str],
    concept_key: str = "",
    used_concepts: Optional[set[str]] = None,
    history_concepts: Optional[set[str]] = None,
) -> bool:
    if not question_hash:
        return False
    if question_hash in used_hashes or question_hash in history_hashes or question_hash in excluded_hashes:
        return False
    if concept_key:
        used_concepts = used_concepts or set()
        history_concepts = history_concepts or set()
        if concept_key in used_concepts or concept_key in history_concepts:
            return False
    return True


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
        "max_tokens": 2500,
    }
    timeout_secs = int(os.environ.get("MISTRAL_TIMEOUT", "10"))
    try:
        resp = requests.post(base_url, headers=headers, json=body, timeout=timeout_secs)
    except requests.exceptions.Timeout:
        raise RuntimeError("Mistral API request timed out")
    except requests.exceptions.RequestException as ex:
        raise RuntimeError(f"Mistral API request failed: {str(ex)[:200]}")
    if resp.status_code != 200:
        raise RuntimeError(f"Mistral API failed: {resp.status_code} {resp.text[:200]}")
    data = resp.json()
    if isinstance(data, dict) and "choices" in data and isinstance(data["choices"], list) and data["choices"]:
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
    return resp.text.strip()


def _parse_question_list(raw: str) -> List[Dict]:
    raw = raw.strip()
    if raw.startswith("```") and raw.endswith("```"):
        raw = raw[3:-3].strip()
    start = raw.find("[")
    end = raw.rfind("]")
    if start >= 0 and end > start:
        raw = raw[start : end + 1]
    data = json.loads(raw)
    if isinstance(data, dict):
        data = data.get("questions", [])
    if not isinstance(data, list):
        return []

    cleaned: List[Dict] = []
    seen = set()
    for item in data:
        if not isinstance(item, dict):
            continue
        question = _clean_text(item.get("question", ""))
        options_text = _question_options(item)
        if not question or len(options_text) != 4:
            continue
        answer_index = _answer_index_from_value(item.get("answer_index", item.get("correct_answer", 0)))
        fingerprint = _question_hash(question, options_text)
        if fingerprint in seen:
            continue
        seen.add(fingerprint)
        subject = _clean_text(item.get("subject", "NEET")) or "NEET"
        unit = _clean_text(item.get("unit", ""))
        concept = _clean_text(item.get("concept", item.get("topic", unit))) or unit or question[:80]
        topic = _clean_text(item.get("topic", unit)) or unit
        passage = _clean_text(item.get("passage", ""))
        cleaned.append(
            {
                "subject": subject,
                "unit": unit,
                "chapter": _clean_text(item.get("chapter", unit)) or unit,
                "question_type": _normalized_question_type(item.get("question_type", "MCQ")),
                "difficulty": _normalized_difficulty(item.get("difficulty", "Medium")),
                "question": question,
                "options": options_text,
                "answer_index": answer_index,
                "correct_answer": _answer_letter_from_index(answer_index),
                "passage": passage,
                "explanation": _clean_text(item.get("explanation", "")),
                "concept": concept,
                "topic": topic,
                "concept_key": _concept_key(subject, unit, concept),
                "hash": fingerprint,
            }
        )
    return cleaned


def _fallback_question_from_source(source: QuestionSource, rng: random.Random) -> Dict:
    difficulty = "Medium"
    return _generic_unit_question(source.subject, source.unit, rng, source.text, difficulty=difficulty)


def _fallback_question_for_unit(subject: str, unit: str, rng: random.Random, difficulty: str = "Medium", variant_index: int = 0) -> Dict:
    return _generic_unit_question(subject, unit, rng, "", difficulty=difficulty, variant_index=variant_index)


def _batch_prompt(subject: str, unit: str, contexts: List[QuestionSource], batch_size: int, excluded_hashes: List[str], target_difficulty: Optional[str] = None) -> str:
    context_lines = []
    for item in contexts:
        snippet = re.sub(r"\s+", " ", item.text).strip()
        if not snippet:
            continue
        context_lines.append(f"- [{item.source}] {snippet[:260]}")
    return (
        "Generate valid JSON only. Return an array of unique NEET quiz questions. "
        f"Generate {batch_size} fresh questions only from the selected chapter/topic: {unit} in {subject}. "
        "Do not include unrelated chapters or mixed-syllabus items. "
        "Each object must include subject, unit, chapter, topic, question_type, difficulty, question, passage, options, correct_answer, explanation, and concept. "
        "Options must contain exactly four answer choices. Use correct_answer as A, B, C, or D. "
        "Keep the wording NEET-style, NCERT-oriented, and grounded in the provided PDF / syllabus context. "
        "Avoid repeating the same concept, wording, numerical values, assertion-reason pair, or diagram scenario. "
        f"Avoid any question whose hash matches these excluded hashes: {excluded_hashes}. "
        "Use only valid JSON and no markdown. "
        + (f"Prefer difficulty: {target_difficulty}. " if target_difficulty else "")
        + "Context snippets:\n"
        + "\n".join(context_lines)
    )


def _topic_prompt(subject: str, topic: str, batch_size: int, excluded_hashes: List[str], target_difficulty: Optional[str] = None) -> str:
    topic_label = _clean_text(topic) or subject
    difficulty_hint = f"Prefer difficulty: {target_difficulty}. " if target_difficulty else ""
    return (
        "Generate valid JSON only. Return an array of unique NEET-style MCQ questions. "
        f"Generate {batch_size} fresh questions only for the selected topic: {topic_label} in {subject}. "
        "Do not include unrelated topics, chapters, or mixed-syllabus items. "
        "Make the questions based on NEET paper style and NCERT-level understanding of this topic. "
        "Each object must include subject, unit, chapter, topic, question_type, difficulty, question, passage, options, correct_answer, explanation, and concept. "
        "Options must contain exactly four answer choices. Use correct_answer as A, B, C, or D. "
        "Avoid repeating the same concept, wording, numerical values, assertion-reason pair, or diagram scenario. "
        f"Avoid any question whose hash matches these excluded hashes: {excluded_hashes}. "
        "Use only valid JSON and no markdown. "
        + difficulty_hint
        + "Target the selected topic only; do not retrieve or quote PDF context."
    )


def _subject_sources(subject: str) -> List[QuestionSource]:
    sources = _question_sources().get(subject, [])
    if sources:
        return sources
    return []


def _generate_subject_questions(subject: str, needed: int, excluded_hashes: List[str], seed: str, target_difficulty: Optional[str] = None) -> List[Dict]:
    sources = _subject_sources(subject)
    rng = random.Random(seed + subject)
    rng.shuffle(sources)
    generated: List[Dict] = []
    used_hashes = set(excluded_hashes)
    history_hashes = set(excluded_hashes)
    api_key = _mistral_api_key()

    if sources and api_key:
        unit_groups: Dict[str, List[QuestionSource]] = {}
        for item in sources:
            unit_groups.setdefault(item.unit or subject, []).append(item)

        units = list(unit_groups.keys()) or [subject]
        rng.shuffle(units)
        batch_guard = 0
        while len(generated) < needed and batch_guard < needed * 2:
            unit = units[batch_guard % len(units)]
            context_pool = unit_groups.get(unit, sources)
            sample_size = min(8, max(4, needed - len(generated)))
            sample = rng.sample(context_pool, k=min(len(context_pool), sample_size)) if context_pool else []
            prompt = _batch_prompt(subject, unit, sample, min(12, needed - len(generated)), excluded_hashes + list(used_hashes), target_difficulty)
            try:
                raw = _call_mistral_generate(api_key, prompt)
                candidates = _parse_question_list(raw)
            except Exception:
                candidates = []

            if not candidates:
                fallback_source = sample[0] if sample else (sources[batch_guard % len(sources)] if sources else None)
                if fallback_source:
                    candidates = [_fallback_question_from_source(fallback_source, rng)]

            for item in candidates:
                options = [str(option).strip() for option in item.get("options", [])[:4]]
                question = str(item.get("question", "")).strip()
                if len(options) != 4 or not question:
                    continue
                qhash = item.get("hash") or _question_hash(question, options)
                if not _question_is_unique(qhash, used_hashes, history_hashes, excluded_hashes):
                    continue
                generated.append(
                    {
                        "subject": subject,
                        "unit": str(item.get("unit", unit)).strip() or unit,
                        "question": question,
                        "options": options,
                        "answer_index": max(0, min(3, int(item.get("answer_index", 0) or 0))),
                        "explanation": str(item.get("explanation", "")).strip(),
                        "hash": qhash,
                    }
                )
                used_hashes.add(qhash)
                if len(generated) >= needed:
                    break
            batch_guard += 1

    if len(generated) < needed:
        fallback_sources = sources[:]
        rng.shuffle(fallback_sources)
        idx = 0
        while len(generated) < needed and fallback_sources:
            src = fallback_sources[idx % len(fallback_sources)]
            candidate = _fallback_question_from_source(src, rng)
            idx += 1
            qhash = candidate["hash"]
            if not _question_is_unique(qhash, used_hashes, history_hashes, excluded_hashes):
                continue
            generated.append(candidate)
            used_hashes.add(qhash)

    return generated[:needed]


def _current_question_pool(user_id: int) -> Dict[str, set[str]]:
    return _history_by_subject(user_id)


def _store_history(user_id: int, session_id: str, questions: List[Dict]) -> None:
    db, cursor = _get_db_cursor(dictionary=False)
    try:
        for item in questions:
            cursor.execute(
                """
                INSERT IGNORE INTO mock_test_question_history
                (user_id, session_id, question_hash, concept_key, subject, unit, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    user_id,
                    session_id,
                    item.get("hash", ""),
                    item.get("concept_key", ""),
                    item.get("subject", "NEET"),
                    item.get("unit", ""),
                    datetime.utcnow(),
                ),
            )
        db.commit()
    finally:
        cursor.close()
        db.close()


def _save_session(user_id: int, session_id: str, questions: List[Dict]) -> None:
    db, cursor = _get_db_cursor(dictionary=False)
    try:
        payload = json.dumps(questions, ensure_ascii=False)
        answers = json.dumps([int(item.get("answer_index", 0)) for item in questions], ensure_ascii=False)
        cursor.execute(
            """
            INSERT INTO mock_test_sessions
            (id, user_id, created_at, status, total_questions, total_marks, duration_seconds, question_payload, answer_key)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
              question_payload = VALUES(question_payload),
              answer_key = VALUES(answer_key),
              status = VALUES(status)
            """,
            (
                session_id,
                user_id,
                datetime.utcnow(),
                "in_progress",
                len(questions),
                TOTAL_MARKS,
                DURATION_SECONDS,
                payload,
                answers,
            ),
        )
        db.commit()
    finally:
        cursor.close()
        db.close()


def _load_session(session_id: str) -> Optional[Dict]:
    db, cursor = _get_db_cursor()
    try:
        cursor.execute("SELECT * FROM mock_test_sessions WHERE id = %s", (session_id,))
        row = cursor.fetchone()
        return row
    finally:
        cursor.close()
        db.close()


def _decode_json_field(value):
    if value in (None, ""):
        return None
    if isinstance(value, (list, dict)):
        return value
    try:
        return json.loads(value)
    except Exception:
        return None


def _load_all_question_history(user_id: int) -> set[str]:
    """Load question hashes from both mock_test and unit_quiz history tables."""
    db, cursor = _get_db_cursor()
    try:
        cursor.execute(
            "SELECT question_hash FROM mock_test_question_history WHERE user_id = %s UNION SELECT question_hash FROM unit_quiz_question_history WHERE user_id = %s",
            (user_id, user_id),
        )
        rows = cursor.fetchall() or []
        return {str(row.get("question_hash", "")) for row in rows if str(row.get("question_hash", "")).strip()}
    finally:
        cursor.close()
        db.close()


def _unit_sources(subject: str, unit: str) -> List[QuestionSource]:
    sources = [s for s in _subject_sources(subject) if (s.unit or "").strip().lower() == (unit or "").strip().lower()]
    return sources


def _generate_unit_questions(
    subject: str,
    unit: str,
    needed: int,
    excluded_hashes: List[str],
    seed: str,
    target_difficulty: Optional[str] = None,
    history_concepts: Optional[set[str]] = None,
) -> List[Dict]:
    rng = random.Random(seed + f":{unit}")
    generated: List[Dict] = []
    used_hashes = set(excluded_hashes)
    history_hashes = set(excluded_hashes)
    concept_history = set(history_concepts or set())
    api_key = _mistral_api_key()

    if api_key:
        batch_guard = 0
        while len(generated) < needed and batch_guard < max(needed * 3, 6):
            prompt = _topic_prompt(subject, unit, min(6, needed - len(generated)), excluded_hashes + list(used_hashes), target_difficulty)
            try:
                raw = _call_mistral_generate(api_key, prompt)
                candidates = _parse_question_list(raw)
            except Exception:
                candidates = []

            for item in candidates:
                options = [_clean_text(option) for option in item.get("options", [])[:4]]
                question = _clean_text(item.get("question", ""))
                if len(options) != 4 or not question:
                    continue
                qhash = item.get("hash") or _question_hash(question, options)
                concept = _clean_text(item.get("concept", item.get("topic", unit))) or unit or question[:80]
                concept_key = _concept_key(subject, unit, concept)
                if not _question_is_unique(qhash, used_hashes, history_hashes, excluded_hashes, concept_key, set(), concept_history):
                    continue
                answer_index = _answer_index_from_value(item.get("answer_index", item.get("correct_answer", 0)))
                generated.append(
                    {
                        "subject": subject,
                        "unit": _clean_text(item.get("unit", unit)) or unit,
                        "chapter": _clean_text(item.get("chapter", unit)) or unit,
                        "question_type": _normalized_question_type(item.get("question_type", "MCQ")),
                        "difficulty": _normalized_difficulty(item.get("difficulty", target_difficulty or "Medium")),
                        "question": question,
                        "options": options,
                        "answer_index": answer_index,
                        "correct_answer": _answer_letter_from_index(answer_index),
                        "passage": _clean_text(item.get("passage", "")),
                        "explanation": _clean_text(item.get("explanation", "")),
                        "concept": concept,
                        "topic": _clean_text(item.get("topic", unit)) or unit,
                        "concept_key": concept_key,
                        "hash": qhash,
                    }
                )
                used_hashes.add(qhash)
                concept_history.add(concept_key)
                if len(generated) >= needed:
                    break
            batch_guard += 1

    if len(generated) < needed:
        idx = 0
        while len(generated) < needed:
            candidate = _fallback_question_for_unit(subject, unit, rng, difficulty=target_difficulty or "Medium", variant_index=idx)
            idx += 1
            qhash = candidate["hash"]
            concept_key = str(candidate.get("concept_key", "")).strip()
            if not _question_is_unique(qhash, used_hashes, history_hashes, excluded_hashes, concept_key, set(), concept_history):
                continue
            generated.append(candidate)
            used_hashes.add(qhash)
            if concept_key:
                concept_history.add(concept_key)

    return generated[:needed]


def _count_unit_quizzes(user_id: int, subject: str, unit: str) -> int:
    db, cursor = _get_db_cursor()
    try:
        cursor.execute("SELECT COUNT(1) as cnt FROM unit_quiz_sessions WHERE user_id = %s AND subject = %s AND unit = %s", (user_id, subject, unit))
        row = cursor.fetchone() or {}
        return int(row.get("cnt", 0) or 0)
    finally:
        cursor.close()
        db.close()


def _pop_rotation_questions(user_id: int, subject: str, unit: str, count: int) -> List[Dict]:
    """Atomically pop up to `count` unused questions from the user's rotation pool."""
    db, cursor = _get_db_cursor(dictionary=False)
    try:
        # use a transaction to select-for-update and mark used
        cursor.execute("START TRANSACTION")
        cursor.execute(
            "SELECT id, question_payload FROM unit_quiz_rotation WHERE user_id = %s AND subject = %s AND unit = %s AND used = 0 ORDER BY created_at LIMIT %s FOR UPDATE",
            (user_id, subject, unit, count),
        )
        rows = cursor.fetchall() or []
        ids = [row[0] for row in rows]
        payloads = [json.loads(row[1]) for row in rows]
        if ids:
            now = datetime.utcnow()
            for rid in ids:
                cursor.execute("UPDATE unit_quiz_rotation SET used = 1, used_at = %s WHERE id = %s", (now, rid))
        db.commit()
        return payloads
    finally:
        cursor.close()
        db.close()


def _build_rotation_pool(user_id: int, subject: str, unit: str, size_hint: int = 100) -> int:
    """Build a rotation pool of up to `size_hint` unique questions for the user/unit.
    Returns the number of questions inserted."""
    inserted = 0
    try:
        # gather unit sources
        sources = _unit_sources(subject, unit) or []
        rng = random.Random(f"{user_id}:{subject}:{unit}:{datetime.utcnow().isoformat()}")
        rng.shuffle(sources)
        candidates: List[Dict] = []

        # First, create fallback candidates from unit sources
        for src in sources:
            if len(candidates) >= size_hint:
                break
            candidates.append(_fallback_question_from_source(src, rng))

        # If still short, try LLM-backed generation for more candidates
        if len(candidates) < size_hint:
            needed = size_hint - len(candidates)
            try:
                extra = _generate_unit_questions(subject, unit, needed, list(_load_all_question_history(user_id)), f"{user_id}:{subject}:{unit}:pool", history_concepts=_load_concept_history(user_id))
                candidates.extend(extra)
            except Exception:
                # ignore LLM failures; rely on fallback
                pass

        # Deduplicate by hash and avoid ones already in user's history or rotation
        existing_hashes = set()
        db, cursor = _get_db_cursor()
        try:
            cursor.execute("SELECT question_hash FROM unit_quiz_rotation WHERE user_id = %s AND subject = %s AND unit = %s", (user_id, subject, unit))
            rows = cursor.fetchall() or []
            for r in rows:
                existing_hashes.add(str(r.get("question_hash", "")).strip())
        finally:
            cursor.close()
            db.close()

        history_hashes = _load_all_question_history(user_id)
        dbi, cursi = _get_db_cursor(dictionary=False)
        try:
            for item in candidates:
                if inserted >= size_hint:
                    break
                qhash = str(item.get("hash", "")).strip()
                if not qhash or qhash in existing_hashes or qhash in history_hashes:
                    continue
                payload = json.dumps(item, ensure_ascii=False)
                rid = str(uuid.uuid4())
                now = datetime.utcnow()
                try:
                    cursi.execute(
                        "INSERT INTO unit_quiz_rotation (id, user_id, subject, unit, question_hash, concept_key, question_payload, used, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                        (rid, user_id, subject, unit, qhash, str(item.get("concept_key", "")).strip(), payload, 0, now),
                    )
                    inserted += 1
                    existing_hashes.add(qhash)
                except Exception:
                    # unique constraint or other issue -> skip
                    continue
            dbi.commit()
        finally:
            cursi.close()
            dbi.close()
    except Exception:
        return inserted
    return inserted


def _save_unit_session(user_id: int, session_id: str, subject: str, unit: str, variant: int, questions: List[Dict]) -> None:
    db, cursor = _get_db_cursor(dictionary=False)
    try:
        payload = json.dumps(questions, ensure_ascii=False)
        answers = json.dumps([int(item.get("answer_index", 0)) for item in questions], ensure_ascii=False)
        cursor.execute(
            """
            INSERT INTO unit_quiz_sessions
            (id, user_id, subject, unit, variant, created_at, status, total_questions, duration_seconds, question_payload, answer_key)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
              question_payload = VALUES(question_payload),
              answer_key = VALUES(answer_key),
              status = VALUES(status)
            """,
            (
                session_id,
                user_id,
                subject,
                unit,
                int(variant),
                datetime.utcnow(),
                "in_progress",
                len(questions),
                UNIT_QUIZ_DURATION,
                payload,
                answers,
            ),
        )
        db.commit()
    finally:
        cursor.close()
        db.close()


def _store_unit_history(user_id: int, session_id: str, questions: List[Dict]) -> None:
    db, cursor = _get_db_cursor(dictionary=False)
    try:
        for item in questions:
            cursor.execute(
                """
                INSERT IGNORE INTO unit_quiz_question_history
                (user_id, session_id, question_hash, concept_key, subject, unit, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    user_id,
                    session_id,
                    item.get("hash", ""),
                    item.get("concept_key", ""),
                    item.get("subject", "NEET"),
                    item.get("unit", ""),
                    datetime.utcnow(),
                ),
            )
        db.commit()
    finally:
        cursor.close()
        db.close()


@router.post("/generate")
def generate_mock_test(req: MockTestGenerateRequest, authorization: Optional[str] = Header(default=None)):
    _ensure_schema()
    user_id = _user_id_from_token(authorization)
    attempt = _count_mock_test_attempts(user_id) + 1
    if attempt > MOCK_TEST_ATTEMPTS_ALLOWED:
        raise HTTPException(status_code=403, detail="Maximum full mock test attempts reached.")
    count = int(req.count or TOTAL_QUESTIONS)
    count = max(TOTAL_QUESTIONS, count)
    count = min(count, TOTAL_QUESTIONS)

    cached_entry = _pop_mock_test_cache(user_id)
    if cached_entry is None:
        _prime_mock_test_cache(user_id)
        cached_entry = _pop_mock_test_cache(user_id)

    if cached_entry is None:
        raise HTTPException(status_code=500, detail="Unable to prepare mock test cache.")

    session_id = req.session_id or cached_entry.session_id
    all_questions = cached_entry.questions[:count]

    if req.exclude_hashes:
        excluded = {str(item).strip() for item in req.exclude_hashes if str(item).strip()}
        if excluded:
            filtered = [item for item in all_questions if str(item.get("hash", "")).strip() not in excluded]
            if len(filtered) == count:
                all_questions = filtered

    _store_history(user_id, session_id, all_questions)
    _save_session(user_id, session_id, all_questions)
    _prime_mock_test_cache(user_id)

    return {
        "session_id": session_id,
        "user_id": user_id,
        "attempt": attempt,
        "attempts_allowed": MOCK_TEST_ATTEMPTS_ALLOWED,
        "attempts_left": max(0, MOCK_TEST_ATTEMPTS_ALLOWED - attempt),
        "duration_seconds": DURATION_SECONDS,
        "total_questions": len(all_questions),
        "total_marks": TOTAL_MARKS,
        "subject_quota": SUBJECT_QUOTAS,
        "questions": all_questions,
    }


@router.post("/preload")
def preload_mock_test_cache(authorization: Optional[str] = Header(default=None), mode: Optional[str] = "now", use_fallback: Optional[bool] = False):
    """Preload mock test cache.
    mode: 'now' (block until ready) or 'async' (start background priming and return immediately)
    use_fallback: if true, use fast fallback-only builder (no LLM) for quicker readiness.
    """
    _ensure_schema()
    user_id = _user_id_from_token(authorization)
    if mode == "async":
        # start background priming if not already running
        with _mock_test_cache_lock:
            if user_id in _mock_test_bg_threads:
                thread = _mock_test_bg_threads[user_id]
                return {"status": "started", "user_id": user_id, "cached_sets": len(_mock_test_cache.get(user_id, deque())), "target_sets": MOCK_TEST_CACHE_TARGET}
            thread = Thread(target=lambda: _background_prime(user_id, bool(use_fallback)))
            thread.daemon = True
            _mock_test_bg_threads[user_id] = thread
            thread.start()
        return {"status": "started", "user_id": user_id, "cached_sets": len(_mock_test_cache.get(user_id, deque())), "target_sets": MOCK_TEST_CACHE_TARGET}
    # default: block until ready
    ready = _prime_mock_test_cache(user_id, use_fallback=bool(use_fallback))
    return {
        "status": "ready",
        "user_id": user_id,
        "cached_sets": ready,
        "target_sets": MOCK_TEST_CACHE_TARGET,
    }


@router.post("/preload/status")
def preload_status(authorization: Optional[str] = Header(default=None)):
    _ensure_schema()
    user_id = _user_id_from_token(authorization)
    with _mock_test_cache_lock:
        cache = _mock_test_cache.get(user_id, deque())
        running = user_id in _mock_test_bg_threads
        return {"status": "running" if running else "idle", "user_id": user_id, "cached_sets": len(cache), "target_sets": MOCK_TEST_CACHE_TARGET}


@router.get("/fixed-set/{set_id}")
def get_fixed_set(set_id: int, authorization: Optional[str] = Header(default=None)):
    _ensure_schema()
    _user_id_from_token(authorization)
    bundle = _load_fixed_set_bundle(set_id)
    return bundle


class UnitQuizGenerateRequest(BaseModel):
    subject: str
    unit: str
    topic: Optional[str] = None
    session_id: Optional[str] = None
    variant: Optional[int] = None


class UnitQuizSubmitRequest(BaseModel):
    session_id: str
    answers: List[Optional[int]] = Field(default_factory=list)
    marked: List[int] = Field(default_factory=list)


@router.post("/unit/generate")
def generate_unit_quiz(req: UnitQuizGenerateRequest, authorization: Optional[str] = Header(default=None)):
    print(f"[mock_test_api] ENTER generate_unit_quiz subject={req.subject} unit={req.unit}")
    try:
        with open(BASE_DIR / 'debug_unit.log', 'a', encoding='utf-8') as df:
            df.write(f"ENTER generate_unit_quiz subject={req.subject} unit={req.unit}\n")
    except Exception:
        pass
    _ensure_schema()
    user_id = _user_id_from_token(authorization)
    print(f"[mock_test_api] user_id resolved: {user_id}")
    try:
        with open(BASE_DIR / 'debug_unit.log', 'a', encoding='utf-8') as df:
            df.write(f"user_id_resolved:{user_id}\n")
    except Exception:
        pass
    subject = (req.subject or "").strip()
    unit = (req.topic or req.unit or "").strip()
    if not subject or not unit:
        raise HTTPException(status_code=400, detail="subject and topic are required")

    taken = _count_unit_quizzes(user_id, subject, unit)
    if taken >= UNIT_QUIZ_VARIANTS:
        raise HTTPException(status_code=403, detail="Maximum quizzes reached for this topic")

    variant = int(req.variant) if req.variant and 1 <= int(req.variant) <= UNIT_QUIZ_VARIANTS else (taken + 1)
    session_id = req.session_id or str(uuid.uuid4())
    seed = f"{user_id}:{subject}:{unit}:{variant}:{datetime.utcnow().date().isoformat()}"

    history_hashes = _load_all_question_history(user_id)
    print(f"[mock_test_api] loaded history hashes: {len(history_hashes)}")
    try:
        with open(BASE_DIR / 'debug_unit.log', 'a', encoding='utf-8') as df:
            df.write(f"history_hashes_count:{len(history_hashes)}\n")
    except Exception:
        pass

    print(f"[mock_test_api] calling _generate_unit_questions for subject={subject} unit={unit}")
    try:
        with open(BASE_DIR / 'debug_unit.log', 'a', encoding='utf-8') as df:
            df.write(f"calling_generate_unit_questions:{subject}:{unit}\n")
    except Exception:
        pass
    questions = _generate_unit_questions(subject, unit, UNIT_QUIZ_COUNT, list(history_hashes), seed, history_concepts=_load_concept_history(user_id))
    print(f"[mock_test_api] generated {len(questions)} questions from generator")
    try:
        with open(BASE_DIR / 'debug_unit.log', 'a', encoding='utf-8') as df:
            df.write(f"generated_count:{len(questions)}\n")
    except Exception:
        pass
    # Deduplicate by hash (preserve order)
    seen_hashes = set()
    unique_questions: List[Dict] = []
    for q in questions:
        h = str(q.get("hash", "")).strip()
        if not h or h in seen_hashes:
            continue
        seen_hashes.add(h)
        unique_questions.append(q)
    questions = unique_questions[:UNIT_QUIZ_COUNT]

    if len(questions) < UNIT_QUIZ_COUNT:
        # Enforce difficulty distribution only when we still need to fill the quiz.
        DIFF_TARGET = {"Easy": 3, "Medium": 5, "Hard": 2}
        diff_counts = {k: 0 for k in DIFF_TARGET.keys()}
        for q in questions:
            d = str(q.get("difficulty", "")).title()
            if d not in diff_counts:
                d = "Medium"
            diff_counts[d] += 1

        missing_total = sum(max(0, DIFF_TARGET[d] - diff_counts.get(d, 0)) for d in DIFF_TARGET)
        gen_attempts = 0
        max_attempts = 6
        while missing_total > 0 and gen_attempts < max_attempts and len(questions) < UNIT_QUIZ_COUNT:
            for diff, target in DIFF_TARGET.items():
                have = diff_counts.get(diff, 0)
                need = max(0, target - have)
                if need <= 0:
                    continue
                try:
                    extra = _generate_unit_questions(subject, unit, need, list(history_hashes) + list(seen_hashes), seed, target_difficulty=diff, history_concepts=_load_concept_history(user_id))
                except Exception:
                    extra = []
                for item in extra:
                    h = str(item.get("hash", "")).strip()
                    if not h or h in seen_hashes or h in history_hashes:
                        continue
                    questions.append(item)
                    seen_hashes.add(h)
                    diff_counts[str(item.get("difficulty", "")).title() or "Medium"] = diff_counts.get(str(item.get("difficulty", "")).title() or "Medium", 0) + 1
                    if len(questions) >= UNIT_QUIZ_COUNT:
                        break
            missing_total = sum(max(0, DIFF_TARGET[d] - diff_counts.get(d, 0)) for d in DIFF_TARGET)
            gen_attempts += 1

    if len(questions) < UNIT_QUIZ_COUNT:
        raise HTTPException(status_code=500, detail="Unable to generate enough unique unit-quiz questions.")

    try:
        _store_unit_history(user_id, session_id, questions)
        _save_unit_session(user_id, session_id, subject, unit, variant, questions)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to save unit quiz session: {str(exc)[:200]}")

    quiz = {
        "subject": subject,
        "unit": unit,
        "chapter": unit,
        "topic": unit,
        "attempt": variant,
        "attempts_allowed": UNIT_QUIZ_VARIANTS,
        "duration_minutes": UNIT_QUIZ_DURATION // 60,
        "total_questions": len(questions),
        "questions": questions,
    }

    return {
        "success": True,
        "session_id": session_id,
        "user_id": user_id,
        "duration_seconds": UNIT_QUIZ_DURATION,
        "total_questions": len(questions),
        "quiz": quiz,
        "questions": questions,
        "variant": variant,
        "attempt": variant,
        "attempts_allowed": UNIT_QUIZ_VARIANTS,
        "attempts_left": max(0, UNIT_QUIZ_VARIANTS - variant),
    }


@router.post("/unit/submit")
def submit_unit_quiz(req: UnitQuizSubmitRequest, authorization: Optional[str] = Header(default=None)):
    _ensure_schema()
    user_id = _user_id_from_token(authorization)
    db, cursor = _get_db_cursor()
    try:
        cursor.execute("SELECT * FROM unit_quiz_sessions WHERE id = %s", (req.session_id,))
        row = cursor.fetchone()
    finally:
        cursor.close()
        db.close()

    if not row:
        raise HTTPException(status_code=404, detail="Unit quiz session not found.")
    if int(row.get("user_id") or 0) != user_id:
        raise HTTPException(status_code=403, detail="This session does not belong to the authenticated user.")

    questions = _decode_json_field(row.get("question_payload")) or []
    answer_key = _decode_json_field(row.get("answer_key")) or []
    answers = list(req.answers or [])
    marked = sorted({int(index) for index in (req.marked or []) if str(index).isdigit() or isinstance(index, int)})

    correct = 0
    wrong = 0
    unanswered = 0
    score = 0

    for index, question in enumerate(questions):
        selected = answers[index] if index < len(answers) else None
        answer_index = int(answer_key[index]) if index < len(answer_key) else int(question.get("answer_index", 0) or 0)
        if selected is None:
            unanswered += 1
            continue
        try:
            selected_int = int(selected)
        except Exception:
            selected_int = -1
        if selected_int == answer_index:
            correct += 1
            score += 1
        else:
            wrong += 1

    answered = correct + wrong
    accuracy = 0.0 if answered == 0 else round((correct / answered) * 100, 2)
    max_score = len(questions) * 1
    performance = 0.0 if max_score == 0 else round((max(0, min(score, max_score)) / max_score) * 100, 2)

    dbu, cursu = _get_db_cursor(dictionary=False)
    try:
        cursu.execute(
            """
            UPDATE unit_quiz_sessions
            SET submitted_at = %s,
                status = %s,
                submitted_answers = %s,
                marked = %s,
                score = %s,
                correct_count = %s,
                wrong_count = %s,
                unanswered_count = %s,
                accuracy = %s
            WHERE id = %s AND user_id = %s
            """,
            (
                datetime.utcnow(),
                "submitted",
                json.dumps(answers, ensure_ascii=False),
                json.dumps(marked, ensure_ascii=False),
                score,
                correct,
                wrong,
                unanswered,
                accuracy,
                req.session_id,
                user_id,
            ),
        )
        dbu.commit()
    finally:
        cursu.close()
        dbu.close()

    # Return score and correct answers/explanations
    return {
        "session_id": req.session_id,
        "score": score,
        "max_score": max_score,
        "correct": correct,
        "wrong": wrong,
        "unanswered": unanswered,
        "answered": answered,
        "accuracy": accuracy,
        "performance": performance,
        "answer_key": answer_key,
        "questions": questions,
    }


@router.post("/submit")
def submit_mock_test(req: MockTestSubmitRequest, authorization: Optional[str] = Header(default=None)):
    _ensure_schema()
    user_id = _user_id_from_token(authorization)
    row = _load_session(req.session_id)
    if not row:
        raise HTTPException(status_code=404, detail="Mock test session not found.")
    if int(row.get("user_id") or 0) != user_id:
        raise HTTPException(status_code=403, detail="This session does not belong to the authenticated user.")

    questions = _decode_json_field(row.get("question_payload")) or []
    answer_key = _decode_json_field(row.get("answer_key")) or []
    answers = list(req.answers or [])
    marked = sorted({int(index) for index in (req.marked or []) if str(index).isdigit() or isinstance(index, int)})

    correct = 0
    wrong = 0
    unanswered = 0
    score = 0
    subject_stats: Dict[str, Dict[str, int]] = {}

    for index, question in enumerate(questions):
        subject = str(question.get("subject", "NEET")).strip() or "NEET"
        subject_stats.setdefault(subject, {"correct": 0, "wrong": 0, "unanswered": 0, "score": 0, "total": 0})
        subject_stats[subject]["total"] += 1
        selected = answers[index] if index < len(answers) else None
        answer_index = int(answer_key[index]) if index < len(answer_key) else int(question.get("answer_index", 0) or 0)
        if selected is None:
            unanswered += 1
            subject_stats[subject]["unanswered"] += 1
            continue
        try:
            selected_int = int(selected)
        except Exception:
            selected_int = -1
        if selected_int == answer_index:
            correct += 1
            score += 4
            subject_stats[subject]["correct"] += 1
            subject_stats[subject]["score"] += 4
        else:
            wrong += 1
            score -= 1
            subject_stats[subject]["wrong"] += 1
            subject_stats[subject]["score"] -= 1

    answered = correct + wrong
    accuracy = 0.0 if answered == 0 else round((correct / answered) * 100, 2)
    max_score = len(questions) * 4
    performance = 0.0 if max_score == 0 else round((max(0, min(score, max_score)) / max_score) * 100, 2)

    db, cursor = _get_db_cursor(dictionary=False)
    try:
        cursor.execute(
            """
            UPDATE mock_test_sessions
            SET submitted_at = %s,
                status = %s,
                submitted_answers = %s,
                marked = %s,
                score = %s,
                correct_count = %s,
                wrong_count = %s,
                unanswered_count = %s,
                accuracy = %s,
                subject_stats = %s
            WHERE id = %s AND user_id = %s
            """,
            (
                datetime.utcnow(),
                "submitted",
                json.dumps(answers, ensure_ascii=False),
                json.dumps(marked, ensure_ascii=False),
                score,
                correct,
                wrong,
                unanswered,
                accuracy,
                json.dumps(subject_stats, ensure_ascii=False),
                req.session_id,
                user_id,
            ),
        )
        db.commit()
    finally:
        cursor.close()
        db.close()

    return {
        "session_id": req.session_id,
        "score": score,
        "max_score": max_score,
        "correct": correct,
        "wrong": wrong,
        "unanswered": unanswered,
        "answered": answered,
        "accuracy": accuracy,
        "performance": performance,
        "subject_stats": subject_stats,
    }


@router.get("/session/{session_id}")
def get_mock_test_session(session_id: str, authorization: Optional[str] = Header(default=None)):
    _ensure_schema()
    user_id = _user_id_from_token(authorization)
    row = _load_session(session_id)
    if not row:
        raise HTTPException(status_code=404, detail="Mock test session not found.")
    if int(row.get("user_id") or 0) != user_id:
        raise HTTPException(status_code=403, detail="This session does not belong to the authenticated user.")

    question_payload = _decode_json_field(row.get("question_payload")) or []
    subject_stats = _decode_json_field(row.get("subject_stats")) or {}
    return {
        "session_id": session_id,
        "user_id": user_id,
        "status": row.get("status"),
        "created_at": row.get("created_at"),
        "submitted_at": row.get("submitted_at"),
        "duration_seconds": row.get("duration_seconds") or DURATION_SECONDS,
        "total_questions": row.get("total_questions") or len(question_payload),
        "total_marks": row.get("total_marks") or TOTAL_MARKS,
        "score": row.get("score"),
        "correct": row.get("correct_count"),
        "wrong": row.get("wrong_count"),
        "unanswered": row.get("unanswered_count"),
        "accuracy": row.get("accuracy"),
        "subject_stats": subject_stats,
        "questions": question_payload,
    }
