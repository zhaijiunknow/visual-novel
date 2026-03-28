"""
使用全新 token 检查所有表
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

# 所有要检查的表（包括已知和隐藏的）
CHECK_TABLES = [
    ("tblCjPtCWMLcKCS7", "演出表"),
    ("tbli3JZz1BSky0F1", "角色"),
    ("tblM0dppDn6ieanh", "场景"),
    ("tbl6BmpwfWlZZNql", "表情"),
    ("tblfJaAJJurvAjqO", "身体"),
]


def get_new_token(app_id: str, app_secret: str) -> str:
    """获取新的 token"""
    url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    payload = {"app_id": app_id, "app_secret": app_secret}
    response = requests.post(url, json=payload, timeout=30)
    result = response.json()

    if result.get("code") == 0:
        print(f"Token 过期时间: {result.get('expire')} 秒")
    return result.get("tenant_access_token")


def main():
    print("="*60)
    print(f"多维表格 APP_TOKEN: {APP_TOKEN}")
    print("="*60)

    try:
        # 获取新 token
        print("\n[1/2] 获取新的 Access Token...")
        token = get_new_token(APP_ID, APP_SECRET)
        print(f"✅ Token: {token[:30]}...")

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; charset=utf-8"
        }

        # 检查所有表
        print("\n[2/2] 检查所有表...")
        print("="*60)

        for table_id, table_name in CHECK_TABLES:
            url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{table_id}"
            response = requests.get(url, headers=headers, timeout=30)

            status = "✅" if response.status_code == 200 else f"❌({response.status_code})"
            print(f"{status} {table_name:8s} | ID: {table_id}")

            if response.status_code == 200:
                try:
                    data = response.json().get("data", {})
                    print(f"      实际表名: {data.get('name')}")
                    print(f"      修订版本: {data.get('revision')}")
                    print(f"      可见性: {data.get('visible', 'unknown')}")
                except:
                    print(f"      无法解析响应")
            else:
                print(f"      响应: {response.text[:100]}")
            print("-"*60)

    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
