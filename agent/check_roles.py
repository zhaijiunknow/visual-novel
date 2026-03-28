"""
检查角色表数据
"""

import os
import sys
import requests
import json
from dotenv import load_dotenv

sys.stdout.reconfigure(encoding='utf-8')
load_dotenv("C:/Users/kotta/Documents/Godot/visual-novel/python/feishu.env")

APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")
ROLE_TABLE_ID = "tbli3JZz1BSky0F1"


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

    # 获取角色记录
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{ROLE_TABLE_ID}/records/search"
    response = requests.post(url, headers=headers, json={
        "automatic_fields": False,
        "limit": 100
    }, timeout=30)
    result = response.json()

    print(f"响应: {json.dumps(result, indent=2, ensure_ascii=False)}")


if __name__ == "__main__":
    main()
