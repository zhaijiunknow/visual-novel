import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
from dotenv import load_dotenv
import os

load_dotenv('feishu.env')

APP_ID = os.getenv('APP_ID')
APP_SECRET = os.getenv('APP_SECRET')
APP_TOKEN = os.getenv('APP_TOKEN')
TABLE_ID = 'tblM0dppDn6ieanh'

# 获取 token
resp = requests.post('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal', json={'app_id': APP_ID, 'app_secret': APP_SECRET})
token = resp.json()['tenant_access_token']

# 获取所有记录
url = f'https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{TABLE_ID}/records/search'
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
payload = {'automatic_fields': False, 'limit': 5}
resp = requests.post(url, headers=headers, json=payload, timeout=30)
result = resp.json()

print('飞书返回数据：')
print(result)
