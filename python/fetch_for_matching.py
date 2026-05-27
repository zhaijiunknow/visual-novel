"""从飞书拉取余洛琛无语音的记录 + new 文件夹语音列表，输出 JSON 供匹配"""
import requests
import os
import json
import sys
from pathlib import Path
from feishu_auth import get_tenant_token, APP_TOKEN

sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent

PERFORMANCE_TABLE_ID = "tblCjPtCWMLcKCS7"
BASE_URL = "https://open.feishu.cn/open-apis"
VOICE_DIR = REPO_ROOT / "assets" / "voice" / "余洛琛" / "new"

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
        if not result.get("data", {}).get("has_more", False):
            break
        page_token = result["data"]["page_token"]
    return all_records

def extract_text(field_value):
    if isinstance(field_value, str):
        return field_value
    if isinstance(field_value, list):
        return "".join(item.get("text", "") for item in field_value if isinstance(item, dict))
    return ""

def main():
    print("获取 token...")
    token = get_tenant_token()

    print("拉取演出表记录...")
    records = search_all_records(token)

    # 筛选余洛琛无语音的记录
    unmatched = []
    for r in records:
        fields = r.get("fields", {})
        character = extract_text(fields.get("角色"))
        voice = fields.get("语音")
        if character == "余洛琛" and not voice:
            text = extract_text(fields.get("文字")).strip()
            # 去掉首尾引号
            text = text.strip('\u201c\u201d\u2018\u2019"\'「」')
            record_id = r["record_id"]
            unmatched.append({
                "record_id": record_id,
                "text": text
            })

    print(f"余洛琛无语音记录: {len(unmatched)} 条")

    # 获取 new 文件夹语音文件名
    voice_files = []
    for f in sorted(os.listdir(VOICE_DIR)):
        if f.endswith('.wav'):
            voice_files.append(f[:-4])  # 去掉 .wav

    print(f"new 文件夹语音文件: {len(voice_files)} 个")

    # 输出 JSON 供匹配
    output = {
        "voice_files": voice_files,
        "records": unmatched
    }

    out_path = os.path.join(os.path.dirname(__file__), "matching_data.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    print(f"\n已保存到 {out_path}")

if __name__ == "__main__":
    main()
