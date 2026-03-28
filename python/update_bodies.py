import requests
import os
import sys
import io
import json
from dotenv import load_dotenv
from pydash import _
from feishu_auth import get_tenant_token

sys.stdout.reconfigure(encoding='utf-8')
load_dotenv("feishu.env")

# 设置 UTF-8 编码输出
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# 数据表ID
BODY_TABLE_ID = "tblfJaAJJurvAjqO"  # 动作数据表
CHARACTER_TABLE_ID = "tbli3JZz1BSky0F1"  # 角色数据表

# 字段名
CHARACTER_NAME_FIELD = "名称"  # 角色数据表中的角色名
LINK_CHARACTER_FIELD = "角色"  # 动作数据表中关联角色的字段

# 角色目录
CHARACTERS_DIR = r"C:\Users\kotta\Documents\Godot\visual-novel\characters\instances"

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

def find_character_id(name: str) -> str:
    rows = requests.post(
        f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{CHARACTER_TABLE_ID}/records/search",
        headers={"Authorization": f"Bearer {get_tenant_token()}"},
        json={"limit": 100}
    )

    data = rows.json()["data"]["items"]
    
    result = _.find(data, 
        lambda x: _.get(x, "fields.名称[0].text") == name
    )
    if result:
        return result["record_id"]
    return None

def find_body_id(name: str) -> str:
    rows = requests.post(
        f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{BODY_TABLE_ID}/records/search",
        headers={"Authorization": f"Bearer {get_tenant_token()}"},
        json={"limit": 100}
    )

    data = rows.json()["data"]["items"]
    
    result = _.find(data, 
        lambda x: _.get(x, "fields.名称.value[0].text") == name
    )
    if result:
        return result["record_id"]
    return None

def test():
    update_bodies()
    return
    print("获取飞书 token...")
    token = get_tenant_token()
    print(f"Token: {token[:20]}...")

    # rows = requests.post(
    #     f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{CHARACTER_TABLE_ID}/records/search",
    #     headers={"Authorization": f"Bearer {token}"},
    #     json={"limit": 100}
    # )

    rows = requests.post(
        f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ACTION_TABLE_ID}/records/search",
        headers={"Authorization": f"Bearer {token}"},
        json={"limit": 100}
    )

    json = rows.json()

    data = json["data"]["items"]

    # result = _.find(data, 
    #     lambda x: _.get(x, "fields.名称[0].text") == "葛城"
    # )

    print(data)

    # # 写入文件
    # with open("character_records.json", "w", encoding="utf-8") as f:
    #     json.dump(rows.json(), f, indent=2, ensure_ascii=False)

    # print(f"Token: {token[:20]}...")

    # resp = requests.post(
    #     f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ACTION_TABLE_ID}/records",
    #     headers={"Authorization": f"Bearer {token}"},
    #     json={"fields": {LINK_CHARACTER_FIELD: "葛城", "服装": "默认", "动作": "手抬起"}}
    # )

    # resp.json()

def update_bodies():
    token = get_tenant_token()
    for filename in os.listdir(CHARACTERS_DIR):
        if filename.endswith('.tscn'):
            filepath = os.path.join(CHARACTERS_DIR, filename)
            print(f"\n处理文件: {filename}")
            character_name, animations = parse_tscn_file(filepath)
            character_id = find_character_id(character_name)
            print(f"  角色: {character_id}")

            # 过滤出动作（带"-"的）
            actions = [a for a in animations if is_action(a)]
            print(f"  找到 {len(actions)} 个动作")

            for anim_name in actions:
                costume, action = parse_animation_name(anim_name)
                print(f"    - {anim_name} -> 服装: {costume}, 动作: {action}")

                resp = requests.post(
                    f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{BODY_TABLE_ID}/records",
                    headers={"Authorization": f"Bearer {token}"},
                    json={"fields": {"角色": [character_id], "服装": costume, "动作": action}}
                )
                print(resp.json())

def main():
    update_bodies()

if __name__ == "__main__":
    main()
    # test()
