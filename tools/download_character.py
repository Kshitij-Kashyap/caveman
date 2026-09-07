import urllib.request
import os

resource_id = "e992e5f8-3bea-4cca-80e7-8dac71689884"
extensions = ["glb", "fbx", "zip", "gltf", "bin", "obj"]

out_dir = "d:/Godot/troll/assets/models/character/rafael"
os.makedirs(out_dir, exist_ok=True)

for ext in extensions:
    url = f"https://static.poly.pizza/{resource_id}.{ext}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        with urllib.request.urlopen(req) as resp:
            content_type = resp.headers.get('Content-Type')
            content_length = resp.headers.get('Content-Length')
            print(f"FOUND: {url} -> Content-Type: {content_type}, Length: {content_length}")
            data = resp.read()
            out_file = os.path.join(out_dir, f"rigged_character.{ext}")
            with open(out_file, "wb") as f:
                f.write(data)
            print(f"  Saved to {out_file} ({len(data)} bytes)")
    except Exception as e:
        print(f"Not found: {url} -> {e}")
