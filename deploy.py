import os
import sys
import urllib.request
import urllib.error

api_key = os.environ.get('ROBLOX_API_KEY', '').strip()
universe_id = "10767702058"
place_id = "133713004710836"
rbxl_path = "StealAPetRock.rbxl"

print(f"Checking environment...")
print(f"API Key present: {bool(api_key)} (Length: {len(api_key)})")
print(f"Place file exists: {os.path.exists(rbxl_path)} (Size: {os.path.getsize(rbxl_path) if os.path.exists(rbxl_path) else 0} bytes)")

if not api_key:
    print("::error title=Roblox Deploy Diagnostic::ROBLOX_API_KEY is empty or not set in GitHub Secrets")
    print("❌ ERROR: ROBLOX_API_KEY is empty!")
    sys.exit(1)

if not os.path.exists(rbxl_path):
    print("❌ ERROR: StealAPetRock.rbxl not found!")
    sys.exit(1)

with open(rbxl_path, 'rb') as f:
    data = f.read()

url = f"https://apis.roblox.com/universes/v1/{universe_id}/places/{place_id}/versions?versionType=Published"
req = urllib.request.Request(
    url,
    data=data,
    headers={
        'x-api-key': api_key,
        'Content-Type': 'application/octet-stream'
    },
    method='POST'
)

print(f"Sending request to: {url}...")
try:
    with urllib.request.urlopen(req) as resp:
        body = resp.read().decode('utf-8', errors='ignore')
        print(f"✅ Success! Status: {resp.status}")
        print(f"Roblox Response: {body}")
except urllib.error.HTTPError as e:
    err_body = e.read().decode('utf-8', errors='ignore').strip()
    msg = f"HTTP {e.code}: {err_body}".replace("\r", "").replace("\n", " ").replace("%", "%25")
    print(f"::error title=Roblox Deploy Diagnostic::{msg}")
    print(f"❌ Roblox HTTP Error {e.code}: {err_body}")
    sys.exit(1)
except Exception as e:
    msg = f"Unexpected: {str(e)}".replace("\r", "").replace("\n", " ")
    print(f"::error title=Roblox Deploy Diagnostic::{msg}")
    print(f"❌ Unexpected Error: {e}")
    sys.exit(1)
