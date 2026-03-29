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
        params = {}
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


def extract_text(field_value):
    """从飞书字段值中提取纯文本"""
    if field_value is None:
        return ""
    if isinstance(field_value, str):
        return field_value
    if isinstance(field_value, list):
        return "".join(item.get("text", "") for item in field_value if isinstance(item, dict))
    if isinstance(field_value, dict):
        # Formula 字段的值通常在 value 里
        if "value" in field_value:
            return extract_text(field_value["value"])
        if "text" in field_value:
            return field_value["text"]
    return str(field_value)


def extract_field(fields, name):
    """提取字段值，处理各种飞书字段类型"""
    val = fields.get(name)
    if val is None:
        return ""
    # Checkbox
    if isinstance(val, bool):
        return val
    # SingleSelect
    if isinstance(val, str):
        return val
    # Formula 结果
    if isinstance(val, list):
        parts = []
        for item in val:
            if isinstance(item, dict):
                parts.append(item.get("text", ""))
            elif isinstance(item, str):
                parts.append(item)
        return "".join(parts)
    if isinstance(val, (int, float)):
        return str(val)
    return str(val)


def record_to_dialogue_line(fields):
    """将一条演出表记录转换为 dialogue 格式的行"""
    character = extract_field(fields, "角色名称")
    text = extract_field(fields, "文字")
    instruction = extract_field(fields, "指令")
    voice = extract_field(fields, "语音")
    nickname = extract_field(fields, "昵称")
    hide_avatar = fields.get("隐藏头像", False)
    hide_portrait = fields.get("隐藏立绘", False)
    body = extract_field(fields, "身体")
    expression = extract_field(fields, "表情")
    bg_name = extract_field(fields, "背景名称")
    time_period = extract_field(fields, "时段")

    return {
        "character": character,
        "text": text,
        "instruction": instruction,
        "voice": voice,
        "nickname": nickname,
        "hide_avatar": hide_avatar,
        "hide_portrait": hide_portrait,
        "body": body,
        "expression": expression,
        "bg_name": bg_name,
        "time_period": time_period,
    }


def build_dialogue_line(data):
    """构建一行 dialogue 格式的文本"""
    character = data["character"]
    text = data["text"]

    if not character and not text:
        return None

    # 构建 tags
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

    # 确保文字有引号
    if text and not text.startswith('\u201c') and not text.startswith('"'):
        text = f"\u201c{text}\u201d"

    char_name = character if character else "独白"
    return f"{char_name}: {tag_str}{text}"


def build_mutation_lines(data, prev_data):
    """生成 do 指令行（场景切换等）"""
    lines = []

    # 场景/背景变化时插入 SetBackground
    if data["bg_name"] and data["time_period"]:
        if not prev_data or data["bg_name"] != prev_data["bg_name"] or data["time_period"] != prev_data["time_period"]:
            lines.append(f'do SetBackground("{data["bg_name"]}", "{data["time_period"]}", 0, 0.5)')

    return lines


def convert_to_dialogue(records, chapter_filter=None):
    """将演出表记录转换为 dialogue 文件内容"""
    lines = ["~ start"]

    prev_data = None
    for record in records:
        fields = record.get("fields", {})
        data = record_to_dialogue_line(fields)

        # 按章节过滤
        chapter = extract_field(fields, "章节")
        if chapter_filter and chapter != chapter_filter:
            continue

        # 生成 do 指令
        mutations = build_mutation_lines(data, prev_data)
        lines.extend(mutations)

        # 生成对话行
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

    # 先检查数据结构：打印前几条记录的字段
    if "--dump" in sys.argv:
        print("\n[DUMP] 前 5 条记录:")
        for i, record in enumerate(records[:5]):
            fields = record.get("fields", {})
            print(f"\n--- 记录 {i+1} ---")
            for k, v in fields.items():
                print(f"  {k}: {repr(v)}")
        # 统计章节
        chapters = {}
        for record in records:
            ch = extract_field(record.get("fields", {}), "章节")
            chapters[ch] = chapters.get(ch, 0) + 1
        print(f"\n章节分布: {chapters}")
        # 统计指令
        instructions = {}
        for record in records:
            inst = extract_field(record.get("fields", {}), "指令")
            if inst:
                instructions[inst] = instructions.get(inst, 0) + 1
        print(f"指令分布: {instructions}")
        return

    # 获取章节列表
    chapters = {}
    for record in records:
        ch = extract_field(record.get("fields", {}), "章节")
        if ch:
            chapters[ch] = chapters.get(ch, 0) + 1
    print(f"\n章节: {chapters}")

    # 指定章节或全部导出
    chapter_filter = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None

    if chapter_filter:
        print(f"\n[2] 转换章节: {chapter_filter}")
        content = convert_to_dialogue(records, chapter_filter)
        filename = f"{chapter_filter}.dialogue"
    else:
        # 按章节分别导出
        for ch_name, count in chapters.items():
            print(f"\n[2] 转换章节: {ch_name} ({count} 条)")
            content = convert_to_dialogue(records, ch_name)
            filename = f"{ch_name}.dialogue"
            filepath = os.path.join(OUTPUT_DIR, filename)
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"  已写入: {filepath}")
            # 打印前几行预览
            preview_lines = content.split("\n")[:10]
            for line in preview_lines:
                print(f"  | {line}")
            if len(content.split("\n")) > 10:
                print(f"  | ... (共 {len(content.split(chr(10)))} 行)")
        return

    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"\n已写入: {filepath}")

    # 预览
    preview_lines = content.split("\n")[:20]
    for line in preview_lines:
        print(f"  | {line}")
    total = len(content.split("\n"))
    if total > 20:
        print(f"  | ... (共 {total} 行)")


if __name__ == "__main__":
    main()
