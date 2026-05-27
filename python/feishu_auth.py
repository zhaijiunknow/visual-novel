import requests
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).with_name("feishu.env"))

# 飞书配置
APP_ID = os.getenv("APP_ID")
APP_SECRET = os.getenv("APP_SECRET")
APP_TOKEN = os.getenv("APP_TOKEN")

def get_tenant_token():
    """获取 tenant_access_token"""
    missing = [
        name for name, value in {
            "APP_ID": APP_ID,
            "APP_SECRET": APP_SECRET,
            "APP_TOKEN": APP_TOKEN,
        }.items() if not value
    ]
    if missing:
        raise RuntimeError(f"缺少飞书环境变量: {', '.join(missing)}")

    resp = requests.post(
        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
        json={"app_id": APP_ID, "app_secret": APP_SECRET},
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    if data.get("code") not in (None, 0):
        raise RuntimeError(f"获取 tenant_access_token 失败: {data}")
    token = data.get("tenant_access_token")
    if not token:
        raise RuntimeError(f"获取 tenant_access_token 失败: {data}")
    return token
