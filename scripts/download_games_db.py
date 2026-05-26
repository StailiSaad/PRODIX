"""Download all JSON game files from EveryVideoGameEver and merge into assets/data/games_db.json"""
import json, urllib.request, os, sys

REPO_API = "https://api.github.com/repos/Elbriga14/EveryVideoGameEver/contents/GamesDB"
RAW_BASE = "https://raw.githubusercontent.com/Elbriga14/EveryVideoGameEver/main/GamesDB"
OUTPUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "games_db.json")

def main():
    # List files in GamesDB directory
    with urllib.request.urlopen(REPO_API) as resp:
        files = json.loads(resp.read().decode())

    json_files = [f["name"] for f in files if f["name"].endswith(".json")]
    print(f"Found {len(json_files)} JSON files")

    all_games = []
    for i, fname in enumerate(json_files):
        url = f"{RAW_BASE}/{fname}"
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                data = json.loads(resp.read().decode())
            for entry in data:
                all_games.append({
                    "n": entry.get("Game", ""),
                    "g": "",
                    "p": entry.get("Platform", ""),
                })
            print(f"  [{i+1}/{len(json_files)}] {fname}: {len(data)} games")
        except Exception as e:
            print(f"  [{i+1}/{len(json_files)}] {fname}: FAILED - {e}")

    print(f"\nTotal games: {len(all_games)}")
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(all_games, f, ensure_ascii=False)
    print(f"Written to {OUTPUT}")

if __name__ == "__main__":
    main()
