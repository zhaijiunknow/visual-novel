import requests
import os
import re
import sys
from pathlib import Path
import json
from dotenv import load_dotenv
from pydash import _

# Windows 控制台输出 UTF-8
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv("feishu.env")

# 飞书配置
APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")
TABLE_ID = "tblM0dppDn6ieanh"

def get_tenant_token():
    """获取 tenant_access_token"""
    resp = requests.post(
        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
        json={"app_id": APP_ID, "app_secret": APP_SECRET}
    )
    return resp.json()["tenant_access_token"]

def parse_tres_file(file_path):
    """解析 .tres 文件，提取 title 和 variations 中的时段"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取 title
    title_match = re.search(r'title = "([^"]+)"', content)
    title = title_match.group(1) if title_match else ""

    # 提取 variations 中的键（时段）
    time_periods = []
    variations_match = re.search(r'variations = Dictionary\[String, Texture2D\]\(\{([^}]+)\}\)', content, re.DOTALL)
    if variations_match:
        variations_content = variations_match.group(1)
        # 只提取冒号前面双引号包围的键（忽略 ExtResource）
        time_periods = re.findall(r'"\s*([^"]+)"\s*:', variations_content)

    return {
        "title": title,
        "time_periods": time_periods
    }

def create_record(token, fields):
    """创建飞书记录"""
    resp = requests.post(
        f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        },
        json={"fields": fields}
    )
    return resp.json()

def main():
    backgrounds_dir = Path("C:/Users/kotta/Documents/Godot/visual-novel/data/backgrounds")
    tres_files = list(backgrounds_dir.glob("*.tres"))

    print(f"找到 {len(tres_files)} 个 .tres 文件")

    token = get_tenant_token()
    print(f"获取 token 成功")

    for tres_file in tres_files:
        parsed = parse_tres_file(tres_file)
        print(f"\n处理文件: {tres_file.name}")
        print(f"  名称: {parsed['title']}")
        print(f"  时段: {', '.join(parsed['time_periods'])}")

        # 构造飞书字段格式
        fields = {
            "名称": parsed["title"],
            "时段": parsed["time_periods"]
        }

        # 上传到飞书
        result = create_record(token, fields)
        if result.get("code") == 0:
            print(f"  ✓ 上传成功")
        else:
            print(f"  ✗ 上传失败: {result.get('msg')}")

if __name__ == "__main__":
    main()
