"""
使用本地配置连接飞书多维表格
调试版本：显示完整的API响应
"""

import requests
import os
import sys
import json
from dotenv import load_dotenv

# 设置 UTF-8 编码
sys.stdout.reconfigure(encoding='utf-8')

# 加载环境变量
load_dotenv("feishu.env")

APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")

print(f"APP_ID: {APP_ID}")
print(f"APP_TOKEN: {APP_TOKEN}")


def get_tenant_access_token(app_id: str, app_secret: str) -> str:
    """获取 tenant_access_token"""
    url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    payload = {
        "app_id": app_id,
        "app_secret": app_secret
    }
    response = requests.post(url, json=payload, timeout=30)
    result = response.json()
    print(f"\n获取Token响应: {json.dumps(result, indent=2, ensure_ascii=False)}")

    if result.get("code") == 0:
        return result.get("tenant_access_token")
    else:
        raise Exception(f"获取 token 失败: {result}")


def main():
    try:
        # 1. 获取 access_token
        print("\n" + "=" * 60)
        print("步骤1: 获取 Access Token")
        print("=" * 60)
        access_token = get_tenant_access_token(APP_ID, APP_SECRET)
        print(f"\nToken 获取成功: {access_token[:20]}...")

        # 2. 列出所有数据表
        print("\n" + "=" * 60)
        print("步骤2: 列出所有数据表")
        print("=" * 60)

        url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json; charset=utf-8"
        }

        response = requests.get(url, headers=headers, timeout=30)
        result = response.json()

        print(f"\n完整响应:\n{json.dumps(result, indent=2, ensure_ascii=False)}")

        if result.get("code") == 0:
            tables = result.get("data", {}).get("items", [])
            print(f"\n找到 {len(tables)} 个数据表")

            for idx, table in enumerate(tables, 1):
                print(f"\n{idx}. {table.get('name')} (ID: {table.get('table_id')})")
        else:
            print(f"\n错误: {result}")

    except Exception as e:
        print(f"\n错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
