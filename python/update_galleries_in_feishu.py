"""
同步 galleries 文件夹的 .tres 到飞书 CG 表

字段映射：
- 名称 → .tres 文件名（去掉 .tres 后缀）
- 差分 → .tres 中 variation 的图片文件名列表
"""

import requests
import os
import re
import sys
import io
from pathlib import Path
from dotenv import load_dotenv
from feishu_auth import get_tenant_token, APP_TOKEN

sys.stdout.reconfigure(encoding='utf-8')
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
load_dotenv("feishu.env")

TABLE_ID = "tblVOoD2P6EoOHYe"
BASE_URL = "https://open.feishu.cn/open-apis"


def parse_gallery_tres(file_path):
    """解析 gallery .tres，提取文件名和 variation 图片名"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    name = Path(file_path).stem

    # 建立 id -> path 映射（兼容 id/path 两种顺序）
    id_to_path = {}
    for m in re.finditer(r'\[ext_resource[^\]]*id="([^"]+)"[^\]]*path="([^"]+)"', content):
        id_to_path[m.group(1)] = m.group(2)
    for m in re.finditer(r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', content):
        id_to_path[m.group(2)] = m.group(1)

    # 提取 variation 中的 ext_resource id
    variations = []
    var_match = re.search(r'variation = Array\[Texture2D\]\(\[([^\]]+)\]\)', content)
    if var_match:
        ext_ids = re.findall(r'ExtResource\("([^"]+)"\)', var_match.group(1))
        for ext_id in ext_ids:
            path = id_to_path.get(ext_id)
            if path:
                variations.append(Path(path).stem)

    return {"name": name, "variations": variations}


def get_all_records(token):
    all_records = []
    page_token = None
    while True:
        params = {"page_size": 100}
        if page_token:
            params["page_token"] = page_token
        resp = requests.get(
            f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records",
            headers={"Authorization": f"Bearer {token}"},
            params=params,
            timeout=60
        )
        result = resp.json()
        if result.get("code") != 0:
            raise Exception(f"获取记录失败: {result}")
        items = result.get("data", {}).get("items", [])
        all_records.extend(items)
        if not result.get("data", {}).get("has_more", False):
            break
        page_token = result["data"]["page_token"]
    return all_records


def update_record(token, record_id, fields):
    url = f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records/{record_id}"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    return requests.put(url, headers=headers, json={"fields": fields}).json()


def create_record(token, fields):
    url = f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    return requests.post(url, headers=headers, json={"fields": fields}).json()


def main():
    galleries_dir = Path(__file__).parent.parent / "data" / "galleries"
    tres_files = sorted(galleries_dir.glob("*.tres"))
    print(f"找到 {len(tres_files)} 个 .tres 文件")

    token = get_tenant_token()
    print("获取 token 成功")

    all_records = get_all_records(token)
    print(f"获取到 {len(all_records)} 条记录")

    # 建立名称 -> record 映射（每个 CG 一行）
    name_to_record = {}
    for record in all_records:
        fields = record.get("fields", {})
        name = fields.get("名称", "")
        if isinstance(name, list):
            name = name[0] if name else ""
        if name:
            name_to_record[name] = record

    for tres_file in tres_files:
        parsed = parse_gallery_tres(tres_file)
        print(f"\n处理: {tres_file.name}")
        print(f"  名称: {parsed['name']}")
        print(f"  差分 ({len(parsed['variations'])}): {', '.join(parsed['variations'])}")

        record = name_to_record.get(parsed["name"])

        if record:
            record_id = record.get("record_id")
            print(f"  已存在 (ID: {record_id})，更新差分")
            # PUT 会覆盖整个 record，必须合并已有 fields
            existing_fields = record.get("fields", {})
            existing_fields["差分"] = parsed["variations"]
            result = update_record(token, record_id, existing_fields)
            if result.get("code") == 0:
                print("  OK 更新成功")
            else:
                print(f"  FAIL 更新失败: {result.get('msg')}")
        else:
            fields = {
                "名称": parsed["name"],
                "差分": parsed["variations"]
            }
            result = create_record(token, fields)
            if result.get("code") == 0:
                print("  OK 创建成功")
            else:
                print(f"  FAIL 创建失败: {result.get('msg')}")


if __name__ == "__main__":
    main()
