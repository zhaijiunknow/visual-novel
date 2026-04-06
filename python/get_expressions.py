"""
从飞书多维表格获取表情数据 - GDScript版本

使用方法：
    1. 在下方"配置区域"填写你的飞书应用凭证
    2. 运行: python scripts/fetch_expression_data.py

如何获取飞书应用凭证：
    1. 访问 https://open.feishu.cn/app 创建应用
    2. 在"凭证与基础信息"获取 App ID 和 App Secret
    3. 在"权限管理"添加权限：bitable:record:read 和 bitable:record
    4. 在多维表格中添加应用为协作者

详细教程：docs/feishu_config_guide.md
"""

import requests
import json
import os
import sys
import io
from typing import Dict, List, Any

# Fix encoding issue on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


# ==================== 配置区域 ====================
# 请填写你的飞书应用凭证

APP_ID = "cli_a922b15b84789bdb"        # 替换为你的 App ID
APP_SECRET = "7izYC4vTwwY0TOAuZ6jezhRUXjgUfWHH"   # 替换为你的 App Secret

# ================================================


# 多维表格配置（无需修改）
APP_TOKEN = "VVSGbFpmEaDwcjskj1qchmi0nAh"
TABLE_ID = "tbl6BmpwfWlZZNql"
VIEW_ID = None  # 不指定视图，获取所有记录
OUTPUT_PATH = "../autoloads/expressions.gd"


class FeishuExpressionFetcher:
    """飞书多维表格表情数据获取器"""

    def __init__(self, app_token: str, access_token: str):
        self.app_token = app_token
        self.access_token = access_token
        self.base_url = "https://open.larkoffice.com/open-apis"

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json; charset=utf-8"
        }

    def search_records(self, table_id: str, view_id: str = None) -> List[dict]:
        """获取记录（支持分页）"""
        all_records = []
        page_token = None
        
        while True:
            url = f"{self.base_url}/bitable/v1/apps/{self.app_token}/tables/{table_id}/records/search"

            payload = {"automatic_fields": False}
            if view_id:
                payload["view_id"] = view_id

            response = requests.post(
                url,
                headers=self._headers(),
                json=payload,
                timeout=30
            )

            result = response.json()

            if result.get("code") != 0:
                raise Exception(f"API错误: {result.get('msg')}")

            data = result.get("data", {})
            items = data.get("items", [])
            all_records.extend(items)
            
            if not data.get("has_more"):
                break
            
            page_token = data.get("page_token")

        return all_records

    def get_field_value(self, value) -> str:
        """获取字段值，处理不同的字段类型
        
        当前数据表字段类型：
        - 角色：单选字段（字符串）
        - 表情：单选字段（字符串）
        - 眉毛：单选字段（字符串）
        - 眼睛：单选字段（字符串）
        - 嘴巴：单选字段（字符串）
        - 角色-表情：公式字段（可能不需要）
        """
        if value is None:
            return ""
        
        # 单选字段：直接是字符串
        if isinstance(value, str):
            return value
        
        # 文本字段：[{text: "xxx", type: "text"}]
        if isinstance(value, list) and len(value) > 0:
            if isinstance(value[0], dict) and "text" in value[0]:
                return value[0].get("text", "")
            # 多选字段：["选项1", "选项2"]
            if isinstance(value[0], str):
                return value[0]
        
        return ""

    def extract_expressions(self, records: List[dict]) -> Dict[str, Any]:
        """从记录中提取表情数据
        
        当前字段结构：
        - 角色 (单选)：角色名称，如"葛城"、"余洛琛"等
        - 表情 (单选)：表情名称
        - 眉毛 (单选)：眉毛状态
        - 眼睛 (单选)：眼睛状态
        - 嘴巴 (单选)：嘴巴状态
        """
        expression_data = {}

        for record in records:
            fields = record.get("fields", {})
            
            # 从"角色"字段获取角色名（单选字段）
            character = self.get_field_value(fields.get("角色"))
            expression_name = self.get_field_value(fields.get("表情"))
            eyebrows = self.get_field_value(fields.get("眉毛"))
            eyes = self.get_field_value(fields.get("眼睛"))
            mouth = self.get_field_value(fields.get("嘴巴"))

            if character and expression_name:
                if character not in expression_data:
                    expression_data[character] = {}

                expression_data[character][expression_name] = {
                    "Eyebrows": eyebrows or "默认",
                    "Eyes": eyes or "默认",
                    "Mouth": mouth or "默认"
                }

        return expression_data

    def fetch_expression_data(self, table_id: str, view_id: str = None) -> Dict[str, Any]:
        """获取表情数据"""
        records = self.search_records(table_id, view_id)
        expression_data = self.extract_expressions(records)
        return expression_data


def get_tenant_access_token(app_id: str, app_secret: str) -> str:
    """获取 tenant_access_token"""
    url = "https://open.larkoffice.com/open-apis/auth/v3/tenant_access_token/internal"

    response = requests.post(
        url,
        json={
            "app_id": app_id,
            "app_secret": app_secret
        },
        timeout=30
    )

    result = response.json()

    if result.get("code") != 0:
        raise Exception(f"获取token失败: {result.get('msg')}")

    return result.get("tenant_access_token")


def dict_to_gdscript(data: dict, indent_level: int = 0) -> str:
    """将字典转换为GDScript格式的字符串"""
    indent = "\t" * indent_level
    lines = []
    items = list(data.items())

    for i, (key, value) in enumerate(items):
        is_last = (i == len(items) - 1)

        if isinstance(value, dict):
            # 嵌套字典
            lines.append(f'{indent}"{key}": {{')
            lines.append(dict_to_gdscript(value, indent_level + 1))
            if is_last:
                lines.append(f'{indent}}}')
            else:
                lines.append(f'{indent}}},')
        else:
            # 字符串值
            if is_last:
                lines.append(f'{indent}"{key}": "{value}"')
            else:
                lines.append(f'{indent}"{key}": "{value}",')

    return "\n".join(lines)


def main():
    """主函数"""

    print("=" * 80)
    print("从飞书多维表格获取表情数据")
    print("=" * 80)

    # 检查配置
    if APP_ID.startswith("cli_") is False or APP_SECRET == "xxxxxxxxxxxxxxxxxx":
        print("\n错误：请先配置飞书应用凭证！")
        print("\n请按照以下步骤操作：")
        print("1. 访问 https://open.feishu.cn/app")
        print("2. 创建企业自建应用")
        print("3. 在'凭证与基础信息'页面获取 App ID 和 App Secret")
        print("4. 编辑脚本第24-25行，填写 APP_ID 和 APP_SECRET")
        print("5. 在'权限管理'中添加权限：")
        print("   - bitable:record:read")
        print("   - bitable:record")
        print("6. 在多维表格中添加应用为协作者")
        return

    try:
        # 获取 access_token
        print("\n正在获取 access_token...")
        access_token = get_tenant_access_token(APP_ID, APP_SECRET)
        print("成功获取 access_token")

        # 创建获取器
        fetcher = FeishuExpressionFetcher(APP_TOKEN, access_token)

        # 获取表情数据
        print("\n正在获取表情数据...")
        expression_data = fetcher.fetch_expression_data(TABLE_ID, VIEW_ID)

        # 生成GDScript格式
        print("\n" + "=" * 80)
        print("生成的GDScript代码：")
        print("=" * 80)

        gdscript_code = """class_name Expressions

static var data = {
"""

        # 添加数据内容
        gdscript_code += dict_to_gdscript(expression_data, indent_level=1)

        gdscript_code += "\n}\n"

        print(gdscript_code)

        # 保存到文件
        output_dir = os.path.dirname(OUTPUT_PATH)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
            f.write(gdscript_code)

        print("\n" + "=" * 80)
        print(f"已保存到: {OUTPUT_PATH}")
        print("=" * 80)

        # 统计信息
        total_characters = len(expression_data)
        total_expressions = sum(len(expressions) for expressions in expression_data.values())

        print(f"\n统计：")
        print(f"   - 角色数量: {total_characters}")
        print(f"   - 表情总数: {total_expressions}")

        for char_name, expressions in expression_data.items():
            print(f"   - {char_name}: {len(expressions)} 个表情")

    except Exception as e:
        print(f"\n错误: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
