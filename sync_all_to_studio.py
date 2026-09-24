import subprocess
import json
import os
import sys

def main():
    mcp_exe = r"C:\Users\rexmc\AppData\Local\Roblox\Versions\version-3afcc74cf8b04b5d\StudioMCP.exe"
    repo_dir = r"C:\GAME-BOBLOX"

    proc = subprocess.Popen(
        [mcp_exe],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    def send_msg(msg):
        proc.stdin.write(json.dumps(msg) + '\n')
        proc.stdin.flush()
        line = proc.stdout.readline()
        return json.loads(line) if line else None

    # 1. Handshake
    send_msg({
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "hermes-sync", "version": "1.0"}}
    })
    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + '\n')
    proc.stdin.flush()

    # 2. Get Studio
    studios_res = send_msg({
        "jsonrpc": "2.0", "id": 2, "method": "tools/call",
        "params": {"name": "list_roblox_studios", "arguments": {}}
    })
    studios = json.loads(studios_res["result"]["content"][0]["text"]).get("studios", [])
    if not studios:
        print("ERROR: No active Roblox Studio instance found!")
        proc.terminate()
        return 1

    studio_id = studios[0]["id"]
    studio_name = studios[0]["name"]
    print(f"Target Studio: {studio_name} ({studio_id})")

    # 3. Ensure Edit Mode
    state_res = send_msg({
        "jsonrpc": "2.0", "id": 3, "method": "tools/call",
        "params": {"name": "get_studio_state", "arguments": {"studio_id": studio_id}}
    })
    if "Mode: Play" in state_res["result"]["content"][0]["text"]:
        print("Switching from Play mode to Edit mode...")
        send_msg({
            "jsonrpc": "2.0", "id": 4, "method": "tools/call",
            "params": {"name": "start_stop_play", "arguments": {"studio_id": studio_id, "is_start": False}}
        })

    dirs_to_scan = [
        (os.path.join(repo_dir, "ReplicatedStorage"), "game.ReplicatedStorage"),
        (os.path.join(repo_dir, "ServerScriptService"), "game.ServerScriptService"),
        (os.path.join(repo_dir, "StarterPlayer", "StarterPlayerScripts"), "game.StarterPlayer.StarterPlayerScripts"),
    ]

    files_to_sync = []
    for base_folder, roblox_root in dirs_to_scan:
        for root, _, files in os.walk(base_folder):
            for file in files:
                if file.endswith(".luau") or file.endswith(".lua"):
                    full_disk_path = os.path.join(root, file)
                    rel_to_base = os.path.relpath(full_disk_path, base_folder)
                    parts = rel_to_base.replace("\\", "/").split("/")
                    parts[-1] = os.path.splitext(parts[-1])[0]
                    if parts[-1] == "init":
                        parts.pop()
                    roblox_path = roblox_root + "." + ".".join(parts)
                    files_to_sync.append((full_disk_path, roblox_path))

    print(f"Checking and syncing {len(files_to_sync)} scripts...\n")

    msg_id = 100
    updated_count = 0
    identical_count = 0
    missing_count = 0

    for disk_path, roblox_path in files_to_sync:
        with open(disk_path, "r", encoding="utf-8") as f:
            disk_source = f.read()

        payload = json.dumps({"source": disk_source})
        escaped_payload = json.dumps(payload)

        sync_code = f"""
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local success, target = pcall(function() return {roblox_path} end)
if not success or not target or not target:IsA("LuaSourceContainer") then
    return "MISSING"
end

local data = HttpService:JSONDecode({escaped_payload})
if target.Source == data.source then
    return "IDENTICAL"
end

local recording = ChangeHistoryService:TryBeginRecording("MCP Sync {os.path.basename(disk_path)}")
target.Source = data.source
if recording then
    ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return "UPDATED"
"""
        msg_id += 1
        res = send_msg({
            "jsonrpc": "2.0", "id": msg_id, "method": "tools/call",
            "params": {
                "name": "execute_luau",
                "arguments": {
                    "studio_id": studio_id,
                    "datamodel_type": "Edit",
                    "code": sync_code
                }
            }
        })

        out = res.get("result", {}).get("content", [{}])[0].get("text", "")
        if "UPDATED" in out:
            print(f"  ✓ [UPDATED] {roblox_path}")
            updated_count += 1
        elif "IDENTICAL" in out:
            identical_count += 1
        elif "MISSING" in out:
            print(f"  ✗ [MISSING] {roblox_path}")
            missing_count += 1
        else:
            print(f"  ! [ERROR] {roblox_path}: {out}")

    print("\n" + "="*50)
    print(f"SYNC RESULT:")
    print(f"  - Updated into Roblox Studio: {updated_count}")
    print(f"  - Already identical: {identical_count}")
    print(f"  - Missing: {missing_count}")
    print(f"  - Total: {len(files_to_sync)}")
    print("="*50)

    proc.terminate()
    return 0

if __name__ == "__main__":
    sys.exit(main())
