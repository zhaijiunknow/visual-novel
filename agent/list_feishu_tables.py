"""
使用本地配置连接飞书多维表格
列出所有数据表及其结构
"""

import requests
import os
import sys
from dotenv import load_dotenv

# 设置 UTF-8 编码
sys.stdout.reconfigure(encoding='utf-8')

# 加载环境变量
load_dotenv("feishu.env")

APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")

if not all([APP_ID, APP_SECRET, APP_TOKEN]):
    print("❌ 错误：请检查 feishu.env 文件中的配置")
    exit(1)


class FeishuBitableClient:
    """飞书多维表格 API 客户端"""

    BASE_URL = "https://open.larkoffice.com/open-apis"

    def __init__(self, app_token: str, access_token: str):
        self.app_token = app_token
        self.access_token = access_token
        self.headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application; charset=utf-8"
        }

    def list_tables(self) -> list:
        """列出多维表格中所有数据表"""
        url = f"{self.BASE_URL}/bitable/v1/apps/{self.app_token}/tables"
        response = requests.get(url, headers=self.headers, timeout=30)
        result = response.json()

        if result.get("code") == 0:
            return result.get("data", {}).get("items", [])
        else:
            raise Exception(f"查询数据表失败: {result}")

    def get_table_fields(self, table_id: str) -> list:
        """获取指定数据表的字段列表"""
        url = f"{self.BASE_URL}/bitable/v1/apps/{self.app_token}/tables/{table_id}/fields"
        response = requests.get(url, headers=self.headers, timeout=30)
        result = response.json()

        if result.get("code") == 0:
            return result.get("data", {}).get("items", [])
        else:
            raise Exception(f"查询字段失败: {result}")

    def search_records(self, table_id: str, limit: int = 100) -> list:
        """搜索数据表中的记录"""
        url = f"{self.BASE_URL}/bitable/v1/apps/{self.app_token}/tables/{table_id}/records/search"
        payload = {
            "automatic_fields": False,
            "limit": limit
        }
        response = requests.post(url, headers=self.headers, json=payload, timeout=30)
        result = response.json()

        if result.get("code") == 0:
            return result.get("data", {}).get("items", [])
        else:
            raise Exception(f"查询记录失败: {result}")


def get_tenant_access_token(app_id: str, app_secret: str) -> str:
    """获取 tenant_access_token"""
    url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"
    payload = {
        "app_id": app_id,
        "app_secret": app_secret
    }
    response = requests.post(url, json=payload, timeout=30)
    result = response.json()

    if result.get("code") == 0:
        return result.get("tenant_access_token")
    else:
        raise Exception(f"获取 token 失败: {result}")


def main():
    print("=" * 60)
    print("飞书多维表格数据表查询")
    print("=" * 60)

    try:
        # 1. 获取 access_token
        print("\n[1/4] 正在连接飞书...")
        access_token = get_tenant_access_token(APP_ID, APP_SECRET)
        print("   ✅ 连接成功")

        # 2. 初始化客户端
        client = FeishuBitableClient(APP_TOKEN, access_token)

        # 3. 列出所有数据表
        print("\n[2/4] 正在获取数据表列表...")
        tables = client.list_tables()
        print(f"   ✅ 找到 {len(tables)} 个数据表\n")

        # 4. 查询每个表的详细信息
        print("[3/4] 正在查询数据表详细信息...")
        print("-" * 60)

        for idx, table in enumerate(tables, 1):
            table_id = table.get("table_id")
            table_name = table.get("name")

            print(f"\n{idx}. 📋 {table_name}")
            print(f"   ID: {table_id}")

            # 查询字段
            fields = client.get_table_fields(table_id)
            print(f"   字段数: {len(fields)}")
            if fields:
                print("   字段列表:")
                for field in fields:
                    field_name = field.get("field_name")
                    field_type = field.get("type")
                    print(f"     - {field_name} ({field_type})")

            # 查询记录数
            records = client.search_records(table_id, limit=1000)
            print(f"   记录数: {len(records)}")

            # 显示前3条记录数据（如果存在）
            if records:
                print("   前3条记录示例:")
                for i, record in enumerate(records[:3], 1):
                    fields_data = record.get("fields", {})
                    print(f"     记录{i}: {fields_data}")

        print("\n[4/4] 查询完成！")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ 错误: {e}")
        exit(1)


if __name__ == "__main__":
    main()
