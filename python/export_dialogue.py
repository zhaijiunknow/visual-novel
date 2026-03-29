import requests
import os
import sys
import json
from dotenv import load_dotenv
from feishu_auth import get_tenant_token, APP_TOKEN

load_dotenv("feishu.env")
sys.stdout.reconfigure(encoding='utf-8')

# 数据表ID
PERFORMANCE_TABLE_ID = "tblCjPtCWMLcKCS7"  # 演出表

BASE_URL = "https://open.feishu.cn/open-apis"

# 输出目录
OUTPUT_DIR = r"C:\Users\kotta\Documents\Godot\visual-novel\dialogue_manager\dialogues"


def get_all_records(token):
    """分页获取演出表所有记录"""
    all_records = []
    page_token = None
    while True:
        params = {"page_size": 100}
        if page_token:
            params["page_token"] = page_token
        resp = requests.get(
            f"{BASE_URL}/bitable/v1/apps/{APP_TOKEN}/tables/{PERFORMANCE_TABLE_ID}/records",
            headers={"Authorization": f"Bearer {token}"},
            params=params,
            timeout=60
        )
        result = resp.json()
        if result.get("code") != 0:
            raise Exception(f"查询记录失败: {result}")
        items = result.get("data", {}).get("items", [])
        all_records.extend(items)
        print(f"  已获取 {len(all_records)} 条记录...")
        if not result.get("data", {}).get("has_more", False):
            break
        page_token = result["data"]["page_token"]
    return all_records


def extract_field(fields, name):
    """提取字段值，处理各种飞书字段类型"""
    val = fields.get(name)
    if val is None:
        return ""
    # Checkbox
    if isinstance(val, bool):
        return val
    # SingleSelect / 普通字符串
    if isinstance(val, str):
        return val
    # 富文本或多值列表
    if isinstance(val, list):
        parts = []
        for item in val:
            if isinstance(item, dict):
                parts.append(item.get("text", ""))
            elif isinstance(item, str):
                parts.append(item)
        return "".join(parts)
    # Formula 结果（嵌套在 value 里）
    if isinstance(val, dict):
        if "value" in val:
            return extract_field({"_": val["value"]}, "_")
        if "text" in val:
            return val["text"]
    if isinstance(val, (int, float)):
        return str(val)
    return str(val)


def record_to_data(fields):
    """将一条演出表记录转换为结构化数据"""
    return {
        "character": extract_field(fields, "角色名称"),
        "text": extract_field(fields, "文字"),
        "voice": extract_field(fields, "语音"),
        "nickname": extract_field(fields, "昵称"),
        "hide_avatar": fields.get("隐藏头像", False),
        "hide_portrait": fields.get("隐藏立绘", False),
        "body": extract_field(fields, "身体"),
        "expression": extract_field(fields, "表情"),
        "bg_name": extract_field(fields, "背景名称"),
        "time_period": extract_field(fields, "时段"),
        "chapter": extract_field(fields, "章节"),
    }


def build_dialogue_line(data):
    """构建一行 dialogue 格式的文本"""
    character = data["character"]
    text = data["text"]

    if not character and not text:
        return None

    # 构建 tags（中文标签，合并在一个方括号内）
    tags = []
    if data["voice"]:
        tags.append(f"#语音={data['voice']}")
    if data["nickname"]:
        tags.append(f"#昵称={data['nickname']}")
    if data["hide_avatar"]:
        tags.append("#隐藏头像")
    if data["hide_portrait"]:
        tags.append("#隐藏立绘")
    if data["body"]:
        tags.append(f"#身体={data['body']}")
    if data["expression"]:
        tags.append(f"#表情={data['expression']}")

    tag_str = f"[{', '.join(tags)}]" if tags else ""

    if character:
        # 有角色的对话行：加中文引号
        if text and not text.startswith("\u201c") and not text.startswith('"'):
            text = f"\u201c{text}\u201d"
        return f"{character}: {tag_str}{text}"
    else:
        # 独白行：不加引号
        return f"独白: {text}"


def build_background_line(data, prev_data):
    """当背景或时段变化时，生成 do SetBackground() 行"""
    if not data["bg_name"] or not data["time_period"]:
        return None
    if prev_data and data["bg_name"] == prev_data["bg_name"] and data["time_period"] == prev_data["time_period"]:
        return None
    return f'do SetBackground("{data["bg_name"]}", "{data["time_period"]}", 0, 0.5)'


def convert_to_dialogue(records, chapter_filter):
    """将演出表记录转换为 dialogue 文件内容"""
    lines = ["~ start"]
    prev_data = None

    for record in records:
        fields = record.get("fields", {})
        data = record_to_data(fields)

        if data["chapter"] != chapter_filter:
            continue

        # 背景变化时插入 do SetBackground
        bg_line = build_background_line(data, prev_data)
        if bg_line:
            lines.append(bg_line)

        # 对话行
        dialogue_line = build_dialogue_line(data)
        if dialogue_line:
            lines.append(dialogue_line)

        prev_data = data

    lines.append("=> END")
    return "\n".join(lines)


def main():
    print("=" * 60)
    print("演出表 → dialogue 文件转换")
    print("=" * 60)

    token = get_tenant_token()

    print("\n[1] 获取演出表记录...")
    records = get_all_records(token)
    print(f"共 {len(records)} 条记录")

    # --dump 模式：打印前几条记录用于调试
    if "--dump" in sys.argv:
        print("\n[DUMP] 前 5 条记录:")
        for i, record in enumerate(records[:5]):
            fields = record.get("fields", {})
            print(f"\n--- 记录 {i+1} ---")
            for k, v in fields.items():
                print(f"  {k}: {repr(v)}")
        chapters = {}
        for record in records:
            ch = extract_field(record.get("fields", {}), "章节")
            chapters[ch] = chapters.get(ch, 0) + 1
        print(f"\n章节分布: {chapters}")
        return

    # 统计章节
    chapters = {}
    for record in records:
        ch = extract_field(record.get("fields", {}), "章节")
        if ch:
            chapters[ch] = chapters.get(ch, 0) + 1
    print(f"\n章节: {chapters}")

    # 确定要导出的章节
    chapter_filter = next((a for a in sys.argv[1:] if not a.startswith("--")), None)

    if chapter_filter:
        # 导出指定章节
        chapters_to_export = {chapter_filter: chapters.get(chapter_filter, 0)}
    else:
        # 导出全部章节
        chapters_to_export = chapters

    for ch_name, count in chapters_to_export.items():
        print(f"\n[2] 转换章节: {ch_name} ({count} 条)")
        content = convert_to_dialogue(records, ch_name)
        filepath = os.path.join(OUTPUT_DIR, f"{ch_name}.dialogue")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  已写入: {filepath}")
        preview = content.split("\n")[:10]
        for line in preview:
            print(f"  | {line}")
        total = len(content.split("\n"))
        if total > 10:
            print(f"  | ... (共 {total} 行)")


if __name__ == "__main__":
    main()
