"""
提取所有角色的身体动画数据，并准备写入飞书
"""

import re
import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

CHARACTERS_DIR = r"C:\Users\kotta\Documents\Godot\visual-novel\characters\instances"


def parse_body_animations(file_path):
    """从角色文件中提取身体动画（第一个SpriteFrames）"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 找到角色名称（从文件名）
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

    # 提取所有动画名称
    pattern = r'"name": &"([^"]+)"'
    animations = re.findall(pattern, animations_text)

    return character_name, animations


def main():
    print("="*70)
    print("提取所有角色的身体动画数据")
    print("="*70)

    all_data = {}

    for filename in os.listdir(CHARACTERS_DIR):
        if filename.startswith('character_') and filename.endswith('.tscn'):
            file_path = os.path.join(CHARACTERS_DIR, filename)
            character_name, animations = parse_body_animations(file_path)

            # 拆分动画为服装和动作
            body_data = []
            for anim in animations:
                # 格式通常是：服装-动作
                if '-' in anim:
                    parts = anim.split('-', 1)
                    if len(parts) == 2:
                        costume, action = parts
                    else:
                        costume, action = parts[0], ''
                else:
                    costume, action = anim, ''

                body_data.append({
                    'animation': anim,
                    'costume': costume,
                    'action': action
                })

            all_data[character_name] = body_data

    # 打印提取的数据
    for character_name, data in sorted(all_data.items()):
        print(f"\n【{character_name}】")
        for item in data:
            print(f"  {item['animation']} → 服装:{item['costume']} 动作:{item['action']}")
        print(f"  共 {len(data)} 个动作")

    print(f"\n{'='*70}")
    print(f"总计：{len(all_data)} 个角色")
    print("="*70)

    return all_data


if __name__ == "__main__":
    data = main()
