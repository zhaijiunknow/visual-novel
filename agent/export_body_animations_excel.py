"""
提取角色身体动画数据并导出为Excel
"""

import re
import os
import sys
import pandas as pd
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

CHARACTERS_DIR = r"C:\Users\kotta\Documents\Godot\visual-novel\characters\instances"
OUTPUT_FILE = r"C:\Users\kotta\Documents\Godot\visual-novel\python\身体动画数据.xlsx"


def parse_body_animations(file_path):
    """从角色文件中提取身体动画"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    character_name = Path(file_path).stem.replace('character_', '')

    # 查找第一个 SpriteFrames（Body的动画）
    sprite_frames_match = re.search(
        r'\[sub_resource type="SpriteFrames" id="[^"]+"\]\nanimations = \[(.*?)\]\n\n\[sub_resource',
        content,
        re.DOTALL
    )

    if not sprite_frames_match:
        return character_name, []

    animations_text = sprite_frames_match.group(1)
    pattern = r'"name": &"([^"]+)"'
    animations = re.findall(pattern, animations_text)

    return character_name, animations


def main():
    print("="*70)
    print("提取角色身体动画数据并导出Excel")
    print("="*70)

    all_data = []

    for filename in sorted(os.listdir(CHARACTERS_DIR)):
        if filename.startswith('character_') and filename.endswith('.tscn'):
            file_path = os.path.join(CHARACTERS_DIR, filename)
            character_name, animations = parse_body_animations(file_path)

            for anim in animations:
                # 拆分服装和动作
                if '-' in anim:
                    parts = anim.split('-', 1)
                    costume, action = parts[0], parts[1]
                else:
                    costume, action = anim, ''

                all_data.append({
                    '角色': character_name,
                    '服装': costume,
                    '动作': action,
                    '角色-服装-动作': f"{character_name}-{costume}-{action}"
                })

    print(f"\n提取到 {len(all_data)} 条数据")

    # 创建DataFrame
    df = pd.DataFrame(all_data, columns=['角色', '服装', '动作', '角色-服装-动作'])

    # 保存为Excel
    df.to_excel(OUTPUT_FILE, index=False, engine='openpyxl')

    print(f"✅ 已保存到: {OUTPUT_FILE}")

    # 按角色分组统计
    print(f"\n{'='*70}")
    print("按角色统计:")
    print(f"{'='*70}")
    for character_name in sorted(df['角色'].unique()):
        count = len(df[df['角色'] == character_name])
        print(f"  {character_name}: {count} 条")


if __name__ == "__main__":
    main()
