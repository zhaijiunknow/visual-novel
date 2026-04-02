"""从飞书获取演出表原始数据并保存为 JSON"""
import json
import sys
import os
from dotenv import load_dotenv
from feishu_auth import get_tenant_token, APP_TOKEN
from export_dialogue import get_all_records

load_dotenv("feishu.env")
sys.stdout.reconfigure(encoding="utf-8")

PERFORMANCE_TABLE_ID = "tblCjPtCWMLcKCS7"
OUTPUT_PATH = os.path.join("data_examples", "performance_records.json")


def main():
    token = get_tenant_token()
    print("正在获取演出表记录...")
    records = get_all_records(token)
    print(f"共 {len(records)} 条记录")

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump({"total": len(records), "items": records}, f, ensure_ascii=False, indent=2)

    print(f"已保存到 {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
