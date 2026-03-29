import requests
import os
import sys
import io
from dotenv import load_dotenv
from feishu_auth import get_tenant_token, APP_TOKEN

load_dotenv("feishu.env")
sys.stdout.reconfigure(encoding='utf-8')

# 数据表ID
PERFORMANCE_TABLE_ID = "tblCjPtCWMLcKCS7"  # 演出表

# 语音文件目录
VOICE_DIR = r"C:\Users\kotta\Documents\Godot\visual-novel\assets\voice"

BASE_URL = "https://open.feishu.cn/open-apis"


def scan_voice_files():
    """扫描语音文件夹，返回 {角色名: [文件名(无后缀)]} 的映射"""
    voice_map = {}
    for character_name in os.listdir(VOICE_DIR):
        character_dir = os.path.join(VOICE_DIR, character_name)
        if not os.path.isdir(character_dir):
            continue
        files = []
        for f in os.listdir(character_dir):
            if f.endswith('.wav'):
                files.append(f[:-4])  # 去掉 .wav 后缀
        voice_map[character_name] = files
        print(f"角色 {character_name}: {len(files)} 个语音文件")
    return voice_map


def get_table_fields(token):
    """获取演出表字段结构"""
    url = f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{PERFORMANCE_TABLE_ID}/fields"
    resp = requests.get(url, headers={"Authorization": f"Bearer {token}"}, timeout=30)
    result = resp.json()
    if result.get("code") != 0:
        raise Exception(f"查询字段失败: {result}")
    fields = result["data"]["items"]
    print("\n演出表字段:")
    for f in fields:
        print(f"  - {f['field_name']} (类型: {f.get('ui_type', f.get('type'))})")
    return fields


def search_all_records(token):
    """分页获取演出表所有记录"""
    all_records = []
    page_token = None
    while True:
        params = {}
        if page_token:
            params["page_token"] = page_token
        resp = requests.get(
            f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{PERFORMANCE_TABLE_ID}/records",
            headers={"Authorization": f"Bearer {token}"},
            params=params,
            timeout=60
        )
        result = resp.json()
        if result.get("code") != 0:
            raise Exception(f"查询记录失败: {result}")
        items = result.get("data", {}).get("items", [])
        all_records.extend(items)
        print(f"  已获取 {len(all_records)} 条记录...")
        if not result.get("data", {}).get("has_more", False):
            break
        page_token = result["data"]["page_token"]
    print(f"共获取 {len(all_records)} 条记录")
    return all_records


def extract_text(field_value):
    """从飞书字段值中提取纯文本"""
    if isinstance(field_value, str):
        return field_value
    if isinstance(field_value, list):
        # 富文本字段: [{"text": "xxx", "type": "text"}, ...]
        return "".join(item.get("text", "") for item in field_value if isinstance(item, dict))
    return ""


def normalize_for_match(text):
    """标准化文本用于匹配：统一省略号、去掉引号"""
    # 统一省略号: …… → …, 多个… → 单个…
    text = text.replace('……', '…').replace('…', '…')
    # 去掉内部引号
    text = text.replace('\u2018', '').replace('\u2019', '').replace('\u201c', '').replace('\u201d', '')
    text = text.replace("'", '').replace('"', '')
    return text


def match_voices(records, voice_map, character_field, dialogue_field):
    """匹配语音文件到记录，返回 [(record_id, voice_value)] 列表"""
    matches = []
    unmatched_records = []

    for record in records:
        fields = record.get("fields", {})
        record_id = record["record_id"]

        # 提取角色名
        character_raw = fields.get(character_field)
        character = extract_text(character_raw)

        # 提取台词（去掉首尾各种引号）
        dialogue_raw = fields.get(dialogue_field)
        dialogue = extract_text(dialogue_raw).strip()
        # 去掉首尾的各种引号
        dialogue = dialogue.strip('\u201c\u201d\u2018\u2019"\'「」')

        if not character or not dialogue:
            continue

        # 跳过已有语音的记录
        # existing_voice = fields.get("语音")
        # if existing_voice:
        #     continue

        # 在对应角色的语音文件中查找匹配
        if character not in voice_map:
            continue

        matched_file = None
        norm_dialogue = normalize_for_match(dialogue)
        best_match = None
        best_len = 0
        for voice_name in voice_map[character]:
            # 去掉语音文件名首尾引号后匹配
            clean_voice = voice_name.strip('\u201c\u201d\u2018\u2019"\'「」')
            norm_voice = normalize_for_match(clean_voice)
            if norm_dialogue.startswith(norm_voice) or norm_voice.startswith(norm_dialogue):
                # 选最长匹配，避免短文本误匹配
                match_len = min(len(norm_voice), len(norm_dialogue))
                if match_len > best_len:
                    best_len = match_len
                    best_match = voice_name
        matched_file = best_match

        if matched_file:
            voice_value = f"{character}/{matched_file}"
            matches.append((record_id, voice_value))
        else:
            unmatched_records.append((character, dialogue[:30]))

    return matches, unmatched_records


def update_records(token, matches, voice_field="语音"):
    """批量更新记录的语音字段"""
    success = 0
    fail = 0
    for record_id, voice_value in matches:
        resp = requests.put(
            f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{PERFORMANCE_TABLE_ID}/records/{record_id}",
            headers={"Authorization": f"Bearer {token}"},
            json={"fields": {voice_field: voice_value}},
            timeout=30
        )
        result = resp.json()
        if result.get("code") == 0:
            success += 1
        else:
            fail += 1
            print(f"  更新失败 {record_id}: {result}")
    print(f"\n更新完成: 成功 {success}, 失败 {fail}")


def main():
    print("=" * 60)
    print("语音更新 - 将语音文件名写入飞书演出表")
    print("=" * 60)

    # 1. 扫描语音文件
    print("\n[1] 扫描语音文件...")
    voice_map = scan_voice_files()

    # 2. 获取 token 和字段结构
    print("\n[2] 获取演出表字段...")
    token = get_tenant_token()
    fields = get_table_fields(token)
    field_names = [f["field_name"] for f in fields]
    print(f"  所有字段: {field_names}")

    # 自动检测角色和台词字段
    character_field = None
    dialogue_field = None
    voice_field = None
    for name in field_names:
        if name == "角色名称":
            character_field = name
        elif "角色" in name or "说话人" in name:
            if not character_field:
                character_field = name
        if "台词" in name or "文字" in name or "对话" in name or "文本" in name:
            dialogue_field = name
        if "语音" in name or "voice" in name.lower():
            voice_field = name

    if not character_field or not dialogue_field:
        print(f"\n无法自动检测字段，请检查字段名:")
        print(f"  角色字段: {character_field}")
        print(f"  台词字段: {dialogue_field}")
        print(f"  语音字段: {voice_field}")
        return

    print(f"\n  角色字段: {character_field}")
    print(f"  台词字段: {dialogue_field}")
    print(f"  语音字段: {voice_field}")

    # 3. 获取所有记录
    print("\n[3] 获取演出表记录...")
    records = search_all_records(token)

    # 4. 匹配
    print("\n[4] 匹配语音文件...")
    matches, unmatched = match_voices(records, voice_map, character_field, dialogue_field)

    print(f"\n匹配结果: {len(matches)} 条匹配")
    for record_id, voice_value in matches:
        print(f"  {voice_value}")

    if unmatched:
        print(f"\n未匹配的有语音角色记录: {len(unmatched)} 条")
        for char, dial in unmatched[:10]:
            print(f"  {char}: {dial}...")

    # 5. 统计未使用的语音文件
    used_voices = {v.split("/")[1] for _, v in matches}
    for char, files in voice_map.items():
        unused = [f for f in files if f not in used_voices]
        if unused:
            print(f"\n{char} 未使用的语音文件 ({len(unused)}):")
            for f in unused[:5]:
                print(f"  {f}")
            if len(unused) > 5:
                print(f"  ...还有 {len(unused) - 5} 个")

    if not matches:
        print("\n没有匹配的记录，退出")
        return

    # 6. 确认后更新
    if "--dry-run" in sys.argv:
        print("\n[dry-run 模式] 不执行更新")
        return

    print(f"\n[6] 更新 {len(matches)} 条记录的「{voice_field}」字段...")
    token = get_tenant_token()
    update_records(token, matches, voice_field)


if __name__ == "__main__":
    main()
