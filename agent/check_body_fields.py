"""
检查身体表的字段信息
"""

import os
import sys
import requests
import json
from dotenv import load_dotenv

sys.stdout.reconfigure(encoding='utf-8')
load_dotenv("feishu.env")

APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")
BODY_TABLE_ID = "tblfJaAJJurvAjqO"


def main():
    # 获取token
    token_url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    token_response = requests.post(token_url, json={
        "app_id": APP_ID,
        "app_secret": APP_SECRET
    }, timeout=30)
    token_result = token_response.json()

    if token_result.get("code") != 0:
        print(f"获取token失败: {token_result}")
        return

    access_token = token_result.get("tenant_access_token")
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json; charset=utf-8"
    }

    # 获取字段信息
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{BODY_TABLE_ID}/fields"
    response = requests.get(url, headers=headers, timeout=30)
    result = response.json()

    if result.get("code") == 0:
        print("身体表字段信息:")
        print("="*70)
        fields = result.get("data", {}).get("items", [])
        for field in fields:
            print(f"字段名: {field.get('field_name')}")
            print(f"  ID: {field.get('field_id')}")
            print(f"  类型: {field.get('type')}")
            print(f"  UI类型: {field.get('ui_type')}")
            print(f"  可更新: {field.get('is_updateable')}")
            print(f"  可创建: {field.get('is_creatable')}")
            print()

        # 获取现有记录示例
        print("现有记录示例:")
        print("="*70)
        records_url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{BODY_TABLE_ID}/records/search"
        records_response = requests.post(records_url, headers=headers, json={
            "automatic_fields": False,
            "limit": 3
        }, timeout=30)
        records_result = records_response.json()

        if records_result.get("code") == 0:
            records = records_result.get("data", {}).get("items", [])
            for record in records:
                print(json.dumps(record.get("fields", {}), indent=2, ensure_ascii=False))
                print("-"*70)


if __name__ == "__main__":
    main()
