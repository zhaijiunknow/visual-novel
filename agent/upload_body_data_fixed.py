"""
提取角色身体动画数据并写入飞书"身体"表（修复版）
"""

import re
import os
import sys
import requests
import json
from pathlib import Path
from dotenv import load_dotenv

sys.stdout.reconfigure(encoding='utf-8')
load_dotenv("C:/Users/kotta/Documents/Godot/visual-novel/python/feishu.env")

APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")

# 表ID
ROLE_TABLE_ID = "tbli3JZz1BSky0F1"     # 角色表
BODY_TABLE_ID = "tblfJaAJJurvAjqO"      # 身体表

CHARACTERS_DIR = r"C:\Users\kotta\Documents\Godot\visual-novel\characters\instances"


def get_token():
    """获取 access token"""
    url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    response = requests.post(url, json={"app_id": APP_ID, "app_secret": APP_SECRET}, timeout=30)
    result = response.json()
    return result.get("tenant_access_token")


def get_role_records(token):
    """获取角色表的所有记录，返回角色名到record_id的映射"""
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"}
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ROLE_TABLE_ID}/records/search"
    payload = {"automatic_fields": False, "limit": 100}
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    result = response.json()

    role_map = {}
    if result.get("code") == 0:
        for record in result.get("data", {}).get("items", []):
            fields = record.get("fields", {})
            # 获取角色名称
            if "名称" in fields and fields["名称"]:
                name = fields["名称"][0]["text"]
                role_map[name] = record["record_id"]

    return role_map


def get_existing_body_records(token):
    """获取身体表的现有记录，返回已存在的组合"""
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"}
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{BODY_TABLE_ID}/records/search"
    payload = {"automatic_fields": False, "limit": 100}
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    result = response.json()

    existing = set()
    if result.get("code") == 0:
        for record in result.get("data", {}).get("items", []):
            fields = record.get("fields", {})
            role = fields.get("角色", {}).get("link_record_ids", [None])[0]
            costume = fields.get("服装", "")
            action = fields.get("动作", "")
            # 使用 record_id 作为唯一标识
            existing.add((role, costume, action))

    return existing


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


def create_body_record(token, character_name, costume, action, role_record_id):
    """创建身体表记录"""
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"}

    # 构造字段数据（只填用户可编辑的字段）
    fields = {
        "角色": {"link_record_ids": [role_record_id]},
        "服装": costume,
        "动作": action
    }

    payload = {"fields": fields}

    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{BODY_TABLE_ID}/records"
    response = requests.post(url, headers=headers, json=payload, timeout=30)

    return response.json()


def main():
    print("="*70)
    print("提取角色身体动画并写入飞书")
    print("="*70)

    # 获取token
    print("\n[1/4] 连接飞书...")
    token = get_token()
    print("✅ 连接成功")

    # 获取角色映射
    print("\n[2/4] 获取角色数据...")
    role_map = get_role_records(token)
    print(f"✅ 找到 {len(role_map)} 个角色: {list(role_map.keys())}")

    # 获取现有记录
    print("\n[3/4] 获取现有数据...")
    existing_records = get_existing_body_records(token)
    print(f"✅ 现有 {len(existing_records)} 条记录")

    # 提取所有角色的动画
    print("\n[4/4] 处理角色动画...")
    print("-"*70)

    total_added = 0
    total_skipped = 0

    for filename in sorted(os.listdir(CHARACTERS_DIR)):
        if filename.startswith('character_') and filename.endswith('.tscn'):
            file_path = os.path.join(CHARACTERS_DIR, filename)
            character_name, animations = parse_body_animations(file_path)

            if character_name not in role_map:
                print(f"\n⚠️  角色 {character_name} 在飞书中不存在，跳过")
                continue

            role_record_id = role_map[character_name]
            print(f"\n📋 {character_name} (ID: {role_record_id})")

            added_count = 0
            skipped_count = 0

            for anim in animations:
                # 拆分服装和动作
                if '-' in anim:
                    parts = anim.split('-', 1)
                    costume, action = parts[0], parts[1]
                else:
                    costume, action = anim, ''

                # 检查是否已存在
                key = (role_record_id, costume, action)
                if key in existing_records:
                    skipped_count += 1
                    print(f"  ⏭️  跳过（已存在）: {costume}-{action}")
                    continue

                # 创建记录
                result = create_body_record(token, character_name, costume, action, role_record_id)

                if result.get("code") == 0:
                    added_count += 1
                    existing_records.add(key)
                    print(f"  ✅ 添加: {costume}-{action}")
                else:
                    print(f"  ❌ 失败: {costume}-{action} - {result}")

            print(f"  → 新增 {added_count} 条，跳过 {skipped_count} 条")
            total_added += added_count
            total_skipped += skipped_count

    print(f"\n{'='*70}")
    print(f"✅ 完成！")
    print(f"   总计新增: {total_added} 条")
    print(f"   总计跳过: {total_skipped} 条")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
