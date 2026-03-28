"""
检查隐藏的表（表情表和身体表）
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

# 已知的表ID
EXPRESSION_TABLE_ID = "tbl6BmpwfWlZZNql"  # 表情表
BODY_TABLE_ID = "tblfJaAJJurvAjqO"        # 身体表


def get_tenant_access_token(app_id: str, app_secret: str) -> str:
    """获取 tenant_access_token"""
    url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    payload = {"app_id": app_id, "app_secret": app_secret}
    response = requests.post(url, json=payload, timeout=30)
    result = response.json()

    if result.get("code") == 0:
        return result.get("tenant_access_token")
    else:
        raise Exception(f"获取 token 失败: {result}")


def check_table(access_token, table_id, table_name):
    """检查指定的表是否存在"""
    print(f"\n{'='*60}")
    print(f"检查: {table_name}")
    print(f"表ID: {table_id}")
    print('='*60)

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json; charset=utf-8"
    }

    # 尝试获取表信息
    url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{table_id}"
    response = requests.get(url, headers=headers, timeout=30)
    print(f"   状态码: {response.status_code}")
    print(f"   原始响应: {response.text[:500]}")

    try:
        result = response.json()
    except Exception as e:
        print(f"   JSON解析失败: {e}")
        return

    if result.get("code") == 0:
        print("✅ 表存在且有权限访问")
        data = result.get("data", {})
        print(f"   表名: {data.get('name')}")
        print(f"   版本: {data.get('revision')}")
        print(f"   可见性: {data.get('visible')}")
        print(f"   完整信息: {json.dumps(data, indent=2, ensure_ascii=False)}")

        # 获取获取字段
        url = f"https://open.larkoffice.com/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{table_id}/fields"
        response = requests.get(url, headers=headers, timeout=30)
        try:
            result = response.json()
        except Exception as e:
            print(f"   字段数据JSON解析失败: {e}")
            return
        if result.get("code") == 0:
            fields = result.get("data", {}).get("items", [])
            print(f"   字段数: {len(fields)}")
            for field in fields:
                print(f"     - {field.get('field_name')} ({field.get('type')})")
    else:
        print(f"❌ 无法访问: {result.get('msg')}")
        print(f"   错误码: {result.get('code')}")
        print(f"   完整响应: {json.dumps(result, indent=2, ensure_ascii=False)}")


def main():
    try:
        access_token = get_tenant_access_token(APP_ID, APP_SECRET)
        print(f"✅ 获取 Token 成功\n")

        # 检查表情表
        check_table(access_token, EXPRESSION_TABLE_ID, "表情表")

        # 检查身体表
        check_table(access_token, BODY_TABLE_ID, "身体表")

    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
