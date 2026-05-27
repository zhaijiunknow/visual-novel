import requests
import os
import sys
import io
from pathlib import Path
from feishu_auth import get_tenant_token, APP_TOKEN

sys.stdout.reconfigure(encoding='utf-8')

# 设置 UTF-8 编码输出
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent

# 数据表ID
ACTION_TABLE_ID = "tblfJaAJJurvAjqO"  # 动作数据表
CHARACTER_TABLE_ID = "tbli3JZz1BSky0F1"  # 角色数据表

# 字段名
CHARACTER_NAME_FIELD = "名称"  # 角色数据表中的角色名
LINK_CHARACTER_FIELD = "角色"  # 动作数据表中关联角色的字段

# 角色目录
CHARACTERS_DIR = REPO_ROOT / "characters" / "instances"

def ensure_character_exists(token, character_name):
    """确保角色存在于角色数据表中，如果不存在则创建"""
    # 先查询角色是否存在
    try:
        resp = requests.get(
            f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{CHARACTER_TABLE_ID}/records",
            headers={"Authorization": f"Bearer {token}"},
            params={"filter": f'{{"{CHARACTER_NAME_FIELD}": ["{character_name}"]}}'},
            timeout=30
        )
    except requests.exceptions.RequestException as e:
        print(f"    查询角色超时: {e}，尝试创建")
        # 假设不存在，尝试创建
        try:
            resp = requests.post(
                f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{CHARACTER_TABLE_ID}/records",
                headers={"Authorization": f"Bearer {token}"},
                json={"fields": {CHARACTER_NAME_FIELD: character_name}},
                timeout=30
            )
            result = resp.json()
            if result.get('code') == 0:
                print(f"    创建角色 {character_name}")
                return True
        except:
            print(f"    创建角色失败，继续使用现有数据")
        return True

    result = resp.json()

    if result.get('data', {}).get('total', 0) > 0:
        print(f"    角色 {character_name} 已存在")
        return True

    # 角色不存在，创建
    try:
        resp = requests.post(
            f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{CHARACTER_TABLE_ID}/records",
            headers={"Authorization": f"Bearer {token}"},
            json={"fields": {CHARACTER_NAME_FIELD: character_name}},
            timeout=30
        )
    except requests.exceptions.RequestException as e:
        print(f"    创建角色超时: {e}，继续使用现有数据")
        return True

    result = resp.json()
    if result.get('code') == 0:
        print(f"    创建角色 {character_name}")
        return True
    else:
        print(f"    创建角色失败: {result}，继续")
        return True

def parse_tscn_file(filepath):
    """解析 tscn 文件，提取角色动作"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取角色名（从文件名）
    character_name = os.path.basename(filepath).replace('character_', '').replace('.tscn', '')

    # 简化：直接在文件中查找所有 "name": &"xxx"
    animations = []
    import re
    name_pattern = r'"name": &"([^"]+)"'
    for name_match in re.finditer(name_pattern, content):
        anim_name = name_match.group(1)
        if anim_name not in animations:  # 去重
            animations.append(anim_name)

    return character_name, animations

def is_action(anim_name):
    """判断是否为动作（带"-"）"""
    return '-' in anim_name

def parse_animation_name(anim_name):
    """解析动画名称，返回（服装，动作）"""
    parts = anim_name.split('-', 1)
    return parts[0], parts[1]

def delete_all_records(token):
    """删除动作数据表中的所有记录"""
    print("正在删除所有现有记录...")

    # 先获取所有记录
    try:
        resp = requests.get(
            f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ACTION_TABLE_ID}/records",
            headers={"Authorization": f"Bearer {token}"},
            timeout=30
        )
    except requests.exceptions.RequestException as e:
        print(f"  获取记录超时或失败: {e}")
        print("  跳过删除步骤，继续添加新数据...")
        return

    result = resp.json()

    if result.get('code') != 0:
        print(f"  获取记录失败: {result}")
        return

    records = result.get('data', {}).get('items', [])
    if not records:
        print("  没有记录需要删除")
        return

    print(f"  找到 {len(records)} 条记录，开始删除...")

    # 使用批量删除接口
    deleted_count = 0
    batch_size = 100  # 每批删除100条
    for i in range(0, len(records), batch_size):
        batch = records[i:i + batch_size]
        record_ids = [r.get('record_id') for r in batch if r.get('record_id')]

        try:
            resp = requests.post(
                f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ACTION_TABLE_ID}/records/batch_delete",
                headers={"Authorization": f"Bearer {token}"},
                json={"requests": [{"record_id": rid} for rid in record_ids]},
                timeout=30
            )
            if resp.json().get('code') == 0:
                deleted_count += len(record_ids)
                print(f"  进度: 已删除 {deleted_count}/{len(records)} 条")
        except requests.exceptions.RequestException as e:
            print(f"  批量删除失败: {e}")
            # 逐条删除
            for record_id in record_ids:
                try:
                    resp = requests.delete(
                        f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ACTION_TABLE_ID}/records/{record_id}",
                        headers={"Authorization": f"Bearer {token}"},
                        timeout=10
                    )
                    if resp.json().get('code') == 0:
                        deleted_count += 1
                except:
                    pass

    print(f"  已删除 {deleted_count} 条记录")

def write_to_feishu(token, character, costume, action):
    """写入飞书表格"""
    resp = requests.post(
        f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ACTION_TABLE_ID}/records",
        headers={"Authorization": f"Bearer {token}"},
        json={"fields": {LINK_CHARACTER_FIELD: [character], "服装": costume, "动作": action}}
    )
    return resp.json()

def main():
    print("获取飞书 token...")
    token = get_tenant_token()
    print(f"Token: {token[:20]}...")

    # 先删除所有现有记录
    delete_all_records(token)

    print(f"\n扫描角色目录: {CHARACTERS_DIR}")

    total_actions = 0
    for filename in os.listdir(CHARACTERS_DIR):
        if filename.endswith('.tscn'):
            filepath = os.path.join(CHARACTERS_DIR, filename)
            print(f"\n处理文件: {filename}")

            character_name, animations = parse_tscn_file(filepath)
            print(f"  角色: {character_name}")

            # 确保角色存在于角色数据表
            if not ensure_character_exists(token, character_name):
                continue

            # 过滤出动作（带"-"的）
            actions = [a for a in animations if is_action(a)]
            print(f"  找到 {len(actions)} 个动作")

            for anim_name in actions:
                costume, action = parse_animation_name(anim_name)
                print(f"    - {anim_name} -> 服装: {costume}, 动作: {action}")

                # 写入飞书
                result = write_to_feishu(token, character_name, costume, action)
                if result.get('code') == 0:
                    total_actions += 1
                else:
                    print(f"      写入失败: {result}")

    print(f"\n完成！共写入 {total_actions} 条记录")

if __name__ == "__main__":
    main()
