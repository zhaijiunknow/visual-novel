"""
飞书多维表格数据表查询示例代码
供 OpenClaw 参考使用

功能：
1. 列出多维表格中所有数据表
2. 查询指定数据表的字段结构
3. 查询指定数据表的数据记录
"""

import requests
import json


# ============================================================
# 配置区域 - 请替换为你的实际配置
# ============================================================

APP_TOKEN = "VVSGbFpmEaDwcjskj1qchmi0nAh"  # 多维表格的 App Token

# 获取 access_token 的方式（根据你的认证方式选择）
# 方式1: 使用 coze_workload_identity（推荐，在 Coze 环境中使用）
def get_access_token_via_coze():
    from coze_workload_identity import Client
    client = Client()
    return client.get_integration_credential("integration-feishu-base")

# 方式2: 直接使用 tenant_access_token（需要自己管理 token）
def get_access_token_via_tenant(app_id: str, app_secret: str) -> str:
    """通过 app_id 和 app_secret 获取 tenant_access_token"""
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


# ============================================================
# API 封装
# ============================================================

class FeishuBitableClient:
    """飞书多维表格 API 客户端"""
    
    BASE_URL = "https://open.larkoffice.com/open-apis"
    
    def __init__(self, app_token: str, access_token: str):
        self.app_token = app_token
        self.access_token = access_token
        self.headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json; charset=utf-8"
        }
    
    def list_tables(self) -> list:
        """
        列出多维表格中所有数据表
        
        API: GET /bitable/v1/apps/{app_token}/tables
        返回: [{"table_id": "xxx", "name": "xxx"}, ...]
        """
        url = f"{self.BASE_URL}/bitable/v1/apps/{self.app_token}/tables"
        response = requests.get(url, headers=self.headers, timeout=30)
        result = response.json()
        
        if result.get("code") == 0:
            return result.get("data", {}).get("items", [])
        else:
            raise Exception(f"查询数据表失败: {result}")
    
    def get_table_fields(self, table_id: str) -> list:
        """
        获取指定数据表的字段列表
        
        API: GET /bitable/v1/apps/{app_token}/tables/{table_id}/fields
        返回: [{"field_id": "xxx", "field_name": "xxx", "type": xxx}, ...]
        """
        url = f"{self.BASE_URL}/bitable/v1/apps/{self.app_token}/tables/{table_id}/fields"
        response = requests.get(url, headers=self.headers, timeout=30)
        result = response.json()
        
        if result.get("code") == 0:
            return result.get("data", {}).get("items", [])
        else:
            raise Exception(f"查询字段失败: {result}")
    
    def search_records(self, table_id: str, limit: int = 100) -> list:
        """
        搜索数据表中的记录
        
        API: POST /bitable/v1/apps/{app_token}/tables/{table_id}/records/search
        返回: [{"record_id": "xxx", "fields": {...}}, ...]
        """
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
    
    def get_table_info(self, table_id: str) -> dict:
        """
        获取数据表基本信息
        
        API: GET /bitable/v1/apps/{app_token}/tables/{table_id}
        """
        url = f"{self.BASE_URL}/bitable/v1/apps/{self.app_token}/tables/{table_id}"
        response = requests.get(url, headers=self.headers, timeout=30)
        result = response.json()
        
        if result.get("code") == 0:
            return result.get("data", {})
        else:
            raise Exception(f"查询表信息失败: {result}")


# ============================================================
# 示例：完整查询流程
# ============================================================

def main():
    print("=" * 80)
    print("飞书多维表格数据表查询示例")
    print("=" * 80)
    
    # 1. 获取 access_token（根据你的环境选择方式）
    # 方式1: Coze 环境
    access_token = get_access_token_via_coze()
    
    # 方式2: 自建应用（需要替换 app_id 和 app_secret）
    # access_token = get_access_token_via_tenant("your_app_id", "your_app_secret")
    
    # 2. 初始化客户端
    client = FeishuBitableClient(APP_TOKEN, access_token)
    
    # 3. 列出所有数据表
    print("\n【步骤1】列出所有数据表")
    print("-" * 40)
    tables = client.list_tables()
    
    for idx, table in enumerate(tables, 1):
        table_id = table.get("table_id")
        table_name = table.get("name")
        print(f"{idx}. {table_name} (ID: {table_id})")
    
    # 4. 查询每个表的详细信息
    print("\n【步骤2】查询每个表的字段和数据量")
    print("-" * 40)
    
    for table in tables:
        table_id = table.get("table_id")
        table_name = table.get("name")
        
        # 查询字段
        fields = client.get_table_fields(table_id)
        
        # 查询记录数
        records = client.search_records(table_id, limit=1000)
        
        print(f"\n📋 {table_name}")
        print(f"   字段数: {len(fields)}")
        print(f"   记录数: {len(records)}")
        print(f"   字段列表:")
        for field in fields:
            field_name = field.get("field_name")
            field_type = field.get("type")
            ui_type = field.get("ui_type", "Unknown")
            print(f"     - {field_name} (类型: {ui_type})")
    
    # 5. 特别验证：表情表和身体表
    print("\n" + "=" * 80)
    print("【特别验证】表情表和身体表")
    print("=" * 80)
    
    # 表情表
    expression_table_id = "tbl6BmpwfWlZZNql"
    print(f"\n🎭 表情表 (ID: {expression_table_id})")
    try:
        fields = client.get_table_fields(expression_table_id)
        records = client.search_records(expression_table_id)
        print(f"   ✅ 存在 - 字段数: {len(fields)}, 记录数: {len(records)}")
    except Exception as e:
        print(f"   ❌ 不存在或无权限: {e}")
    
    # 身体表
    body_table_id = "tblfJaAJJurvAjqO"
    print(f"\n🏃 身体表 (ID: {body_table_id})")
    try:
        fields = client.get_table_fields(body_table_id)
        records = client.search_records(body_table_id)
        print(f"   ✅ 存在 - 字段数: {len(fields)}, 记录数: {len(records)}")
    except Exception as e:
        print(f"   ❌ 不存在或无权限: {e}")
    
    print("\n" + "=" * 80)
    print("查询完成！")
    print("=" * 80)


if __name__ == "__main__":
    main()
