import requests
import json
from dotenv import load_dotenv
from pydash import _
from feishu_auth import get_tenant_token, APP_TOKEN

SCENES_TABLE_ID = "tblM0dppDn6ieanh"

def main():
    rows = requests.post(
        f"https://open.feishu.cn/open-apis/bitable/v1/apps/{APP_TOKEN}/tables/{SCENES_TABLE_ID}/records/search",
        headers={"Authorization": f"Bearer {get_tenant_token()}"},
        json={"limit": 100}
    )

    data = rows.json()

    with open("./data_examples/scene_records.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
