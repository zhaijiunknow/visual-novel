"""
显示所有数据表的详细信息
"""

import requests
import os
import sys
import json
from dotenv import load_dotenv

sys.stdout.reconfigure(encoding='utf-8')
load_dotenv("feishu.env")

APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")


def get_token():
    """获取 access token"""
    url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    response = requests.post(url, json={"app_id": APP_ID, "app_secret": APP_SECRET}, timeout=30)
    result = response.json()
    return result.get("tenant_access_token")


def get_tables(token):
    """获取所有表"""
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"}
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables"
    response = requests.get(url, headers=headers, timeout=30)
    result = response.json()
    return result.get("data", {}).get("items", [])


def get_table_fields(token, table_id):
    """获取表的字段"""
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"}
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{table_id}/fields"
    response = requests.get(url, headers=headers, timeout=30)
    result = response.json()
    return result.get("data", {}).get("items", [])


def get_table_records(token, table_id, limit=5):
    """获取表的记录"""
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"}
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{table_id}/records/search"
    payload = {"automatic_fields": False, "limit": limit}
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    result = response.json()
    return result.get("data", {}).get("items", [])


def main():
    print("="*70)
    print("飞书多维表格 - 所有数据表详情")
    print("="*70)

    token = get_token()
    tables = get_tables(token)

    print(f"\n共找到 {len(tables)} 个数据表:\n")

    for i, table in enumerate(tables, 1):
        table_id = table.get("table_id")
        table_name = table.get("name")
        revision = table.get("revision")

        print(f"{'─'*70}")
        print(f"{i}. {table_name}")
        print(f"   ID: {table_id}")
        print(f"   版本: {revision}")

        # 获取字段
        fields = get_table_fields(token, table_id)
        print(f"   字段数: {len(fields)}")
        if fields:
            print("   字段列表:")
            for field in fields:
                print(f"     • {field.get('field_name')} ({field.get('type')})")

        # 获取记录数和示例
        records = get_table_records(token, table_id, limit=100)
        print(f"   记录数: {len(records)}")

        if records:
            print(f"   前 3 条记录示例:")
            for j, record in enumerate(records[:3], 1):
                fields_data = record.get("fields", {})
                print(f"     [{j}] {json.dumps(fields_data, ensure_ascii=False)}")

    print(f"\n{'='*70}")
    print("查询完成！")
    print("="*70)


if __name__ == "__main__":
    main()
