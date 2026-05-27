import sys
import io
import re
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

backgrounds_dir = Path("E:/Unity/visual-novel/data/backgrounds")
tres_files = list(backgrounds_dir.glob("*.tres"))

print(f"找到 {len(tres_files)} 个 .tres 文件")

data_to_upload = []

for tres_file in sorted(tres_files):
    with open(tres_file, 'r', encoding='utf-8') as f:
        content = f.read()

    title_match = re.search(r'title = "([^"]+)"', content)
    title = title_match.group(1) if title_match else ""

    time_periods = []
    variations_match = re.search(r'variations = Dictionary\[String, Texture2D\]\(\{([^}]+)\}\)', content, re.DOTALL)
    if variations_match:
        variations_content = variations_match.group(1)
        time_periods = re.findall(r'"\s*([^"]+)"\s*:', variations_content)

    if time_periods and title:
        data_to_upload.append({
            "name": title,
            "time_periods": time_periods
        })
        print(f"{title}: {time_periods}")

output_file = backgrounds_dir / "backgrounds_data.json"

import json
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(data_to_upload, f, ensure_ascii=False, indent=2)

print(f"\n已保存到: {output_file}")
