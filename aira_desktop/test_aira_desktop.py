"""
Unit and Integration Tests for AIRA Desktop Agent
Tests FastAPI endpoints, pairing security handshake, auth verification,
kill switch, durable command buffering, and file manager functions.
"""

import os
import tempfile
import pytest
from fastapi.testclient import TestClient

import main
from main import app, get_paired_devices, save_paired_devices, get_command_receipts, save_command_receipt
import file_manager

client = TestClient(app)


class TestAiraDesktopCore:
    def setup_method(self):
        # Reset remote paused state before each test
        main.is_remote_paused = False

    def test_health_check_endpoint(self):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data.get("status") == "healthy"
        assert "version" in data
        assert "hostname" in data

    def test_automation_status_and_kill_switch(self):
        # 1. Initial status
        res = client.get("/automation/status")
        assert res.status_code == 200
        assert res.json().get("is_paused") is False

        # 2. Pause automation
        res_pause = client.post("/automation/pause")
        assert res_pause.status_code == 200
        assert res_pause.json().get("is_paused") is True
        assert main.is_remote_paused is True

        # 3. Resume automation
        res_resume = client.post("/automation/resume")
        assert res_resume.status_code == 200
        assert res_resume.json().get("is_paused") is False
        assert main.is_remote_paused is False

    def test_pairing_request_and_pin_generation(self):
        res = client.post("/pair/request", json={
            "client_name": "Pixel 8 Pro",
            "device_id": "test-device-uuid-1",
            "platform": "android"
        })
        assert res.status_code == 200
        data = res.json()
        assert data.get("status") == "waiting_approval"
        assert data.get("ttl_seconds") == 300

        # Verify active pairing state PIN is a 6-digit string
        pin = main.active_pairing_state.get("pin")
        assert len(pin) == 6
        assert pin.isdigit()

    def test_pairing_confirm_rejects_invalid_pin(self):
        res = client.post("/pair/confirm", json={
            "pin": "000000_invalid",
            "device_id": "test-device-uuid-1",
            "device_name": "Pixel 8 Pro",
            "platform": "android"
        })
        assert res.status_code == 401
        assert "Invalid or expired pairing PIN" in res.json().get("detail", "")

    def test_pairing_full_lifecycle_and_bearer_token(self):
        # 1. Request pairing
        req_res = client.post("/pair/request", json={
            "client_name": "Pixel 8 Pro",
            "device_id": "test-lifecycle-device",
            "platform": "android"
        })
        assert req_res.status_code == 200
        generated_pin = main.active_pairing_state["pin"]

        # 2. Confirm pairing with generated PIN
        confirm_res = client.post("/pair/confirm", json={
            "pin": generated_pin,
            "device_id": "test-lifecycle-device",
            "device_name": "Pixel 8 Pro",
            "platform": "android"
        })
        assert confirm_res.status_code == 200
        token = confirm_res.json().get("device_token")
        assert token is not None
        assert len(token) == 48  # secrets.token_hex(24) is 48 hex chars

        # 3. Authenticate with Bearer token
        status_res = client.get("/pair/status", headers={"Authorization": f"Bearer {token}"})
        assert status_res.status_code == 200
        assert status_res.json().get("paired") is True

        # 4. Access without Bearer token should fail with 401
        unauth_res = client.get("/pair/status")
        assert unauth_res.status_code == 401

        # 5. Remote pause locks commands with 423
        pause_res = client.post("/pair/pause", json={"pause": True})
        assert pause_res.status_code == 200
        locked_res = client.get("/pair/status", headers={"Authorization": f"Bearer {token}"})
        assert locked_res.status_code == 423

        # Unpause
        client.post("/pair/pause", json={"pause": False})

        # 6. Revoke token
        revoke_res = client.post(
            "/pair/revoke",
            json={"device_token": token},
            headers={"Authorization": f"Bearer {token}"}
        )
        assert revoke_res.status_code == 200
        assert revoke_res.json().get("revoked_count") >= 1

        # 7. Access with revoked token should fail with 403
        revoked_access_res = client.get("/pair/status", headers={"Authorization": f"Bearer {token}"})
        assert revoked_access_res.status_code == 403

    def test_legacy_pin_authentication(self):
        res = client.get("/pair/status", headers={"X-AIRA-PIN": main.AIRA_PIN})
        assert res.status_code == 200
        data = res.json()
        assert data.get("paired") is True
        assert data.get("device", {}).get("is_legacy") is True

    def test_command_receipts_bounding(self):
        # Test receipt buffer bounding
        for i in range(260):
            save_command_receipt(f"cmd_{i}", {"status": "executed", "index": i})
        receipts = get_command_receipts()
        assert len(receipts) <= 250


class TestFileManagerCore:
    def test_human_size_formatting(self):
        assert file_manager._human_size(0) == "0 B"
        assert file_manager._human_size(500) == "500 B"
        assert "KB" in file_manager._human_size(2048)
        assert "MB" in file_manager._human_size(2 * 1024 * 1024)
        assert "GB" in file_manager._human_size(3 * 1024 * 1024 * 1024)

    def test_list_directory_valid(self):
        cwd = os.path.dirname(os.path.abspath(__file__))
        result = file_manager.list_directory(cwd)
        assert result.get("success") is True
        assert result.get("count") > 0
        assert any(entry["name"] == "main.py" for entry in result.get("entries", []))

    def test_list_directory_nonexistent(self):
        result = file_manager.list_directory("C:/nonexistent_aira_test_path_12345")
        assert result.get("success") is False
        assert "does not exist" in result.get("error", "")

    def test_read_text_file_valid(self):
        req_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requirements.txt")
        result = file_manager.read_text_file(req_path, max_chars=500)
        assert result.get("success") is True
        assert "fastapi" in result.get("content", "").lower()

    def test_read_text_file_nonexistent(self):
        result = file_manager.read_text_file("C:/nonexistent_file_abc_123.txt")
        assert result.get("success") is False
        assert "File not found" in result.get("error", "")

    def test_system_directory_access_blocked(self):
        # 1. Direct system directories
        res_win = file_manager.list_directory(r"C:\Windows")
        assert res_win.get("success") is False
        assert "blocked for security" in res_win.get("error", "").lower()

        res_pf = file_manager.list_directory(r"C:\Program Files")
        assert res_pf.get("success") is False
        assert "blocked for security" in res_pf.get("error", "").lower()

    def test_path_traversal_to_system_directory_blocked(self):
        # Path traversal using '..' targeting Windows directory
        traversal_path = os.path.join(os.path.expanduser("~"), "..", "..", "Windows")
        res = file_manager.list_directory(traversal_path)
        assert res.get("success") is False
        assert "blocked for security" in res.get("error", "").lower()

    def test_read_system_file_blocked(self):
        res = file_manager.read_text_file(r"C:\Windows\System32\drivers\etc\hosts")
        assert res.get("success") is False
        assert "blocked for security" in res.get("error", "").lower()

    def test_delete_file_safety_guardrails(self):
        # System file deletion blocked
        res_sys = file_manager.delete_file(r"C:\Windows\System32\cmd.exe")
        assert res_sys.get("success") is False
        assert "blocked for security" in res_sys.get("error", "").lower()

        # Root drive deletion blocked
        res_root = file_manager.delete_file("C:\\")
        assert res_root.get("success") is False
        assert "blocked for security" in res_root.get("error", "").lower()

    def test_rename_file_traversal_blocked(self):
        cwd = os.path.dirname(os.path.abspath(__file__))
        test_file = os.path.join(cwd, "test_aira_desktop.py")
        res = file_manager.rename_file(test_file, "../escaped_target.py")
        assert res.get("success") is False
        assert "traversal are not allowed" in res.get("error", "").lower()

    def test_fastapi_file_endpoints_enforce_safety_boundaries(self):
        # API level enforcement
        headers = {"X-AIRA-PIN": main.AIRA_PIN}
        
        # 1. /files/list blocked on C:\Windows
        res_list = client.post("/files/list", json={"path": r"C:\Windows"}, headers=headers)
        assert res_list.status_code == 200
        assert res_list.json().get("success") is False
        assert "blocked for security" in res_list.json().get("error", "").lower()

        # 2. /files/read blocked on C:\Windows
        res_read = client.post("/files/read", json={"path": r"C:\Windows\win.ini"}, headers=headers)
        assert res_read.status_code == 200
        assert res_read.json().get("success") is False
        assert "blocked for security" in res_read.json().get("error", "").lower()


class TestWebSocketTrackpad:
    def test_websocket_trackpad_authentication(self):
        import json
        with client.websocket_connect("/ws/trackpad") as websocket:
            # 1. Authenticate with valid PIN
            websocket.send_text(json.dumps({"pin": main.AIRA_PIN}))
            resp = json.loads(websocket.receive_text())
            assert resp.get("status") == "authenticated"
            assert resp.get("success") is True

            # 2. Send ping, receive pong
            websocket.send_text(json.dumps({"type": "ping"}))
            pong = json.loads(websocket.receive_text())
            assert pong.get("type") == "pong"
            assert "time" in pong

            # 3. Send mouse move (relative 0, 0 for safety in tests)
            websocket.send_text(json.dumps({"type": "move", "dx": 0, "dy": 0}))

    def test_websocket_trackpad_rejects_bad_pin(self):
        import json
        with client.websocket_connect("/ws/trackpad") as websocket:
            websocket.send_text(json.dumps({"pin": "wrong_pin_999999"}))
            resp = json.loads(websocket.receive_text())
            assert resp.get("status") == "unauthorized"

