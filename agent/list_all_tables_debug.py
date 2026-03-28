"""
重新获取所有表列表
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


def main():
    print("="*60)
    print("获取多维表格的所有数据表")
    print("="*60)
    print(f"APP_ID: {APP_ID}")
    print(f"APP_TOKEN: {APP_TOKEN}")

    # 获取 token
    print("\n[1/2] 获取 token...")
    token_url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    token_response = requests.post(token_url, json={
        "app_id": APP_ID,
        "app_secret": APP_SECRET
    }, timeout=30)
    token_result = token_response.json()

    if token_result.get("code") != 0:
        print(f"❌ 获取 token 失败: {token_result}")
        return

    access_token = token_result.get("tenant_access_token")
    print(f"✅ Token: {access_token[:30]}...")

    # 列出所有表
    print("\n[2/2] 列出所有表...")
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json; charset=utf-8"
    }

    tables_url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables"
    print(f"URL: {tables_url}")

    tables_response = requests.get(tables_url, headers=headers, timeout=30)
    print(f"状态码: {tables_response.status_code}")
    print(f"响应: {tables_response.text}")

    if tables_response.status_code == 200:
        data = tables_response.json()
        if data.get("code") == 0:
            tables = data.get("data", {}).get("items", [])
            print(f"\n✅ 找到 {len(tables)} 个表:")
            for i, table in enumerate(tables, 1):
                print(f"\n{i}. {table.get('name')}")
                print(f"   ID: {table.get('table_id')}")
                print(f"   修订版本: {table.get('revision')}")
        else:
            print(f"\n❌ API 错误: {data}")


if __name__ == "__main__":
    main()
