"""匹配结果 + 批量更新飞书语音字段"""
import requests
import sys
import json
from pathlib import Path
from feishu_auth import get_tenant_token, APP_TOKEN

sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = Path(__file__).resolve().parent

PERFORMANCE_TABLE_ID = "tblCjPtCWMLcKCS7"
BASE_URL = "https://open.feishu.cn/open-apis"

# AI 匹配结果: voice_filename → record_id
MATCHES = {
    "……": "recvdnC0y4YED0",
    "事先说明一下": "recvdnC0y4YTZS",
    "今天叫你过来": "recvdnC0y4Nhp6",
    "但是真的很显眼啊": "recvdnC0y4m6Wx",
    "你不是帮我写了几篇": "recvdnC0y4lBzE",
    "你是不知道，之前我一个人去烤肉店的时候": "recvdnC0y4bAI9",
    "你说对吧，周腾！": "recvdnC0y4jeZl",
    "先去烤肉店吧，边吃边说好了": "recvdnC0y41ey7",
    "其他人我不清楚": "recvdnC0y4Kzuo",
    "反正就是不一样": "recvdnC0y4XOin",
    "哎很可惜不对哦": "recvdnC0y4fZFs",
    "啊，不然还有什么事吗": "recvdnC0y4YOYI",
    "在你眼里文学社": "recvdnC0y46Jyc",
    "她…没太为难你吧": "recvdnC0y4CgGd",
    "好啦好啦虽然说": "recvdnC0y4724b",
    "就只是随便扫了两眼": "recvdnC0y4ALWO",
    "我、我知道了，这件事等会儿我会和你解释清楚的": "recvdnC0y4NBX8",
    "我叫你来本来就是想和你说这个的": "recvdnC0y4dWqm",
    "我来这里单纯": "recvdnC0y499WP",
    "我看到你了": "recvdnC0y4Qyo1",
    "有啊猜对了的话": "recvdnC0y4ziwl",
    "现在江城很多烤肉店": "recvdnC0y4TEfq",
    "确实是她的做事风格……": "recvdnC0y4dBME",
    "而且一个人去烤肉店真的很尴尬啊": "recvdnC0y4O8iE",
    "要不你猜猜看": "recvdnC0y4Zwe0",
    "要不边逛边说": "recvdnC0y48zCf",
    "要我说，电烤根本就是对烤肉的亵渎": "recvdnC0y4rTn2",
    "这不一样的": "recvdnC0y4n35j",
    "那个也算！但区区一个菠萝包": "recvdnC0y4LQFk",
}

# 未匹配的语音文件
UNMATCHED = [
    '\u201c因为她本名叫\u2018林凌铃\u2019嘛',
    '\u201c把这么好的肉烤成这样，你确实应该跟它说一声对不起',
    '不是不是！抱歉啊，是我没有说清楚。',
    '今天下午来班上找你的那个人是\u201c30\u201d，现任文学社社长。',
    '你不吃吗',
    '再不吃就要糊了',
    '嗯~果然还是这家店的烤肉好吃…',
    '噗~你可别把这些话当真，这',
    '她啊，夸人的话里面十句有十一句都是假的',
    '抱歉啊，我知道周腾你一直都想问这个事情',
    '有人说什么牛肉不应该烤太老',
    '看不出来你还是个老吃家嘛',
    '真正好的牛肉，即使烤得焦一点',
    '老喜欢先把人捧得高高的，',
    '那个，我、我当然也不是说你丑的意思',
]


def update_records(token, matches):
    success = 0
    fail = 0
    for voice_filename, record_id in matches.items():
        voice_value = f"余洛琛/{voice_filename}"
        resp = requests.put(
            f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{PERFORMANCE_TABLE_ID}/records/{record_id}",
            headers={"Authorization": f"Bearer {token}"},
            json={"fields": {"语音": voice_value}},
            timeout=30
        )
        result = resp.json()
        if result.get("code") == 0:
            success += 1
            print(f"  OK {voice_value} → {record_id}")
        else:
            fail += 1
            print(f"  FAIL {record_id}: {result}")
    return success, fail


def main():
    print(f"匹配结果: {len(MATCHES)} 条匹配, {len(UNMATCHED)} 条未匹配\n")

    # 显示匹配详情
    with open(SCRIPT_DIR / "matching_data.json", "r", encoding="utf-8") as f:
        data = json.load(f)

    record_map = {r["record_id"]: r["text"] for r in data["records"]}

    print("=== 匹配详情 ===")
    for voice_fn, record_id in MATCHES.items():
        text = record_map.get(record_id, "(不在无语音列表中)")
        print(f"  语音: {voice_fn}")
        print(f"  文字: {text}")
        print()

    print("\n=== 未匹配语音 ===")
    for v in UNMATCHED:
        print(f"  - {v}")

    if "--dry-run" in sys.argv:
        print("\n[dry-run] 不执行更新")
        return

    print(f"\n准备更新 {len(MATCHES)} 条记录...")
    confirm = input("确认更新? (y/n): ")
    if confirm.strip().lower() != "y":
        print("已取消")
        return

    token = get_tenant_token()
    success, fail = update_records(token, MATCHES)
    print(f"\n完成: 成功 {success}, 失败 {fail}")


if __name__ == "__main__":
    main()
