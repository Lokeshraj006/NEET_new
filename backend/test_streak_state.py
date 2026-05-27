from datetime import date

from backend.streak_api import _normalize_streak_state


class _Cursor:
    def __init__(self):
        self.executed = []

    def execute(self, query, params):
        self.executed.append((query, params))


def test_normalize_streak_resets_only_current_streak_after_gap():
    cursor = _Cursor()
    state = {
        "current_streak": 4,
        "best_streak": 9,
        "last_completed_date": date(2026, 5, 22),
    }

    normalized = _normalize_streak_state(cursor, user_id=7, state=state, challenge_date=date(2026, 5, 25))

    assert normalized["current_streak"] == 0
    assert normalized["best_streak"] == 9
    assert cursor.executed == [
        ("UPDATE daily_streak_state SET current_streak = 0 WHERE user_id = %s", (7,))
    ]


def test_normalize_streak_keeps_active_run_intact():
    cursor = _Cursor()
    state = {
        "current_streak": 4,
        "best_streak": 9,
        "last_completed_date": date(2026, 5, 24),
    }

    normalized = _normalize_streak_state(cursor, user_id=7, state=state, challenge_date=date(2026, 5, 25))

    assert normalized["current_streak"] == 4
    assert normalized["best_streak"] == 9
    assert cursor.executed == []