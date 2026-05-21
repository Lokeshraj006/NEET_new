import unittest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
import auth

class TestProfileEndpoint(unittest.TestCase):
    def setUp(self):
        self.mock_db = MagicMock()
        self.mock_cursor = self.mock_db.cursor.return_value
        auth.get_db = lambda: self.mock_db
        # Mock JWT verification to bypass external dependencies
        auth._get_user_from_token = lambda auth_header: {"id": 1, "email": "test@example.com"}

    def test_name_only_update(self):
        # User exists and only name changes
        self.mock_cursor.fetchone.side_effect = [
            {"id": 1, "name": "Old Name", "password": "hashed_password", "email": "test@example.com", "photo": None}, # first select
            {"id": 1, "name": "New Name", "password": "hashed_password", "email": "test@example.com", "photo": None}  # second select (updated)
        ]
        req = auth.UpdateProfileRequest(name="New Name")
        try:
            auth.update_profile(req, authorization="Bearer token")
            print("PASS: name-only update")
        except Exception as e:
            print(f"FAIL: name-only update ({e})")

    def test_password_update_success(self):
        # Successful password update
        hashed = auth.hash_password("correct_pass")
        self.mock_cursor.fetchone.side_effect = [
            {"id": 1, "name": "Test", "password": hashed, "email": "t@e.com", "photo": None},
            {"id": 1, "name": "Test", "password": "new_hashed", "email": "t@e.com", "photo": None}
        ]
        req = auth.UpdateProfileRequest(current_password="correct_pass", new_password="newpassword123")
        try:
            auth.update_profile(req, authorization="Bearer token")
            print("PASS: password update with correct current password")
        except Exception as e:
            print(f"FAIL: password update with correct current password ({e})")

    def test_password_update_wrong_current(self):
        # Wrong current password rejection
        hashed = auth.hash_password("correct_pass")
        self.mock_cursor.fetchone.return_value = {"id": 1, "name": "Test", "password": hashed, "email": "t@e.com", "photo": None}
        req = auth.UpdateProfileRequest(current_password="wrong_pass", new_password="newpassword123")
        try:
            auth.update_profile(req, authorization="Bearer token")
            print("FAIL: rejection when current password is wrong (did not raise)")
        except HTTPException as e:
            if e.status_code == 401:
                print("PASS: rejection when current password is wrong")
            else:
                print(f"FAIL: rejection when current password is wrong (status {e.status_code})")
        except Exception as e:
            print(f"FAIL: rejection when current password is wrong ({e})")

if __name__ == '__main__':
    tester = TestProfileEndpoint()
    tester.setUp()
    tester.test_name_only_update()
    tester.setUp()
    tester.test_password_update_success()
    tester.setUp()
    tester.test_password_update_wrong_current()
