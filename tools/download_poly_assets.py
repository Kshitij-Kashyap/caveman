import urllib.request
import re
import json

model_ids = {
    'campfire': '0vzzmM-t8CP',
    'wood_log': 'L4E32Wee6C',
    'tree': '6pwiq7hSrHr'
}

for name, mid in model_ids.items():
    url = f"https://poly.pizza/m/{mid}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        html = urllib.request.urlopen(req).read().decode('utf-8')
        print(f"=== {name} ({mid}) ===")
        # Look for static.poly.pizza or files or download links
        static_links = set(re.findall(r'https://[a-zA-Z0-9\.\-\_\/]+\.(?:zip|glb|gltf|obj|bin|png|jpg)', html))
        print("Model file links:", static_links)
        
        # Look for Next.js or Nuxt data or script tags
        scripts = re.findall(r'<script[^>]*>(.*?)</script>', html, re.DOTALL)
        for s in scripts:
            if mid in s or "Download" in s or "files" in s:
                found_urls = re.findall(r'https://static\.poly\.pizza/[^\s\"\'\<\>]+', s)
                if found_urls:
                    print("Found in script:", set(found_urls))
    except Exception as e:
        print(f"Error {name}: {e}")
