import requests
import os
import sys
import json
from datetime import datetime, timezone, timedelta
from collections import defaultdict

BEIJING_TZ = timezone(timedelta(hours=8))
from dotenv import load_dotenv
from feishu_auth import get_tenant_token, APP_TOKEN

load_dotenv("feishu.env")
sys.stdout.reconfigure(encoding='utf-8')

PERFORMANCE_TABLE_ID = "tblCjPtCWMLcKCS7"  # 演出表
BASE_URL = "https://open.feishu.cn/open-apis"
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
    if isinstance(val, bool):
        return val
    if isinstance(val, str):
        return val
    if isinstance(val, list):
        parts = []
        for item in val:
            if isinstance(item, dict):
                parts.append(item.get("text", ""))
            elif isinstance(item, str):
                parts.append(item)
        return "".join(parts)
    if isinstance(val, dict):
        if "value" in val:
            return extract_field({"_": val["value"]}, "_")
        if "text" in val:
            return val["text"]
    if isinstance(val, (int, float)):
        return str(val)
    return str(val)


def get_parent_id(fields):
    """提取父记录 ID"""
    parent = None
    for key in fields:
        if key.startswith("父记录"):
            parent = fields[key]
            break
    if not parent:
        return None
    if isinstance(parent, list) and parent:
        item = parent[0]
        if isinstance(item, dict):
            ids = item.get("record_ids", [])
            return ids[0] if ids else None
    if isinstance(parent, dict):
        ids = parent.get("link_record_ids", []) or parent.get("record_ids", [])
        return ids[0] if ids else None
    return None


def record_to_data(fields):
    """将一条演出表记录转换为结构化数据"""
    costume = extract_field(fields, "服装")
    action = extract_field(fields, "动作")
    body = f"{costume}-{action}" if costume and action else ""

    # 附加是数组字段，直接取列表
    optionals_raw = fields.get("附加", [])
    if isinstance(optionals_raw, list):
        optionals = [str(item) for item in optionals_raw if item]
    else:
        optionals = []

    return {
        "character": extract_field(fields, "角色"),
        "text": extract_field(fields, "文字"),
        "option": extract_field(fields, "回应选项"),
        "voice": extract_field(fields, "语音"),
        "nickname": extract_field(fields, "昵称"),
        "hide_avatar": fields.get("隐藏头像", False),
        "hide_portrait": fields.get("隐藏立绘", False),
        "body": body,
        "expression": extract_field(fields, "表情"),
        "optionals": optionals,
        "phone": fields.get("手机", False),
        "delay": extract_field(fields, "延迟"),
        "bg_name": extract_field(fields, "场景"),
        "time_period": extract_field(fields, "时段"),
        "date": extract_field(fields, "日期"),
        "week_day": extract_field(fields, "星期"),
        "time": extract_field(fields, "时间"),
        "chapter": extract_field(fields, "章节"),
        "music": extract_field(fields, "音乐"),
    }


# ─── 树构建 ───

def build_tree(records):
    """从扁平记录列表构建父子树"""
    children_map = defaultdict(list)
    roots = []

    for record in records:
        parent_id = get_parent_id(record.get("fields", {}))
        if parent_id:
            children_map[parent_id].append(record)
        else:
            roots.append(record)

    return roots, children_map


# ─── dialogue 行生成 ───

def build_tags(data):
    """构建 tag 字符串"""
    tags = []
    if data["delay"] and data["delay"] != "0":
        tags.append(f"#延迟={data['delay']}")
    if data["phone"]:
        tags.append("#手机")
    if data["voice"]:
        tags.append(f"#语音={data['voice']}")
    if data["nickname"]:
        tags.append(f"#昵称={data['nickname']}")
    if data["hide_avatar"]:
        tags.append("#隐藏头像")
    if data["body"] and data["body"] != "-":
        tags.append(f"#身体={data['body']}")
    if data["expression"] and data["expression"] != "-":
        tags.append(f"#表情={data['expression']}")
    if data["optionals"]:
        tags.append(f"#附加={','.join(data['optionals'])}")
    return f"[{', '.join(tags)}]" if tags else ""


def build_dialogue_line(data):
    """构建一行 dialogue 格式的文本（不含缩进）"""
    character = data["character"]
    text = data["text"]

    if not character and not text:
        return None

    tag_str = build_tags(data)

    if character:
        return f"{character}: {tag_str}{text}"
    else:
        return f"独白: {text}"


def generate_do_commands(data, state, lines, tabs):
    """生成 do 指令行（背景切换、FadeIn、ShowPhone/HidePhone）"""

    # 背景变化 → SetBackground + 清空可见角色
    if data["bg_name"] and data["time_period"]:
        if data["bg_name"] != state["bg_name"] or data["time_period"] != state["time_period"]:
            lines.append(f'{tabs}$> SetBackground("{data["bg_name"]}", "{data["time_period"]}", 0, 0.5)')
            state["bg_name"] = data["bg_name"]
            state["time_period"] = data["time_period"]
            state["visible_characters"].clear()

    # 音乐变化 → SetMusic / StopMusic
    if data["music"] != state["music"]:
        if data["music"]:
            lines.append(f'{tabs}$> SetMusic("{data["music"]}")')
        else:
            lines.append(f'{tabs}$> StopMusic()')
        state["music"] = data["music"]

    # 日期变化 → SetDate（日期、星期、时间任一变化都触发）
    if data["date"] and data["week_day"]:
        date_key = f'{data["date"]}-{data["week_day"]}-{data["time"]}'
        if date_key != state["date_key"]:
            timestamp_ms = int(float(data["date"]))
            dt = datetime.fromtimestamp(timestamp_ms / 1000, tz=BEIJING_TZ)
            month = dt.month
            day = dt.day
            week_day = data["week_day"] + data["time"]
            lines.append(f'{tabs}$> SetDate({month}, {day}, "{week_day}")')
            state["date_key"] = date_key

    # 手机模式切换
    is_phone = bool(data["phone"])
    if is_phone and not state["phone_mode"]:
        lines.append(f"{tabs}$> ShowPhone()")
        state["phone_mode"] = True
    elif not is_phone and state["phone_mode"]:
        lines.append(f"{tabs}$> wait(2)")
        lines.append(f"{tabs}$> HidePhone()")
        state["phone_mode"] = False

    # 角色 FadeIn：有角色 + 隐藏立绘=false + 未在场
    character = data["character"]
    if character and not data["hide_portrait"] and character not in state["visible_characters"]:
        lines.append(f'{tabs}$> Character("{character}").FadeIn("Center")')
        state["visible_characters"].add(character)



# ─── 递归遍历 ───

def walk(record, children_map, indent, lines, state):
    """递归遍历记录树，生成 dialogue 文件内容"""
    data = record_to_data(record.get("fields", {}))
    children = children_map.get(record["record_id"], [])
    tabs = "\t" * indent

    if data["option"]:
        # 回应选项行 → 生成 "- 选项文本"
        lines.append(f"{tabs}- {data['option']}")
        for child in children:
            walk(child, children_map, indent + 1, lines, state)
    else:
        # 普通对话行：先生成 do 指令，再生成对话
        generate_do_commands(data, state, lines, tabs)
        dialogue_line = build_dialogue_line(data)
        if dialogue_line:
            lines.append(f"{tabs}{dialogue_line}")
        for child in children:
            walk(child, children_map, indent, lines, state)


# ─── 章节导出 ───

def convert_chapter(roots, children_map, chapter_filter):
    """将指定章节的记录树转换为 dialogue 文件内容"""
    lines = ["~ start"]
    state = {
        "visible_characters": set(),
        "bg_name": "",
        "time_period": "",
        "date_key": "",
        "phone_mode": False,
        "music": "",
    }

    current_chapter = None
    for root in roots:
        data = record_to_data(root.get("fields", {}))
        if data["chapter"]:
            current_chapter = data["chapter"]
        if current_chapter != chapter_filter:
            continue
        walk(root, children_map, 0, lines, state)

    # 结束时关闭手机
    if state["phone_mode"]:
        lines.append("$> wait(2)")
        lines.append("$> HidePhone()")

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

    # --dump 模式
    if "--dump" in sys.argv:
        print("\n[DUMP] 前 5 条记录:")
        for i, record in enumerate(records[:5]):
            fields = record.get("fields", {})
            print(f"\n--- 记录 {i+1} (id={record.get('record_id', '?')}) ---")
            for k, v in fields.items():
                print(f"  {k}: {repr(v)}")

        # 统计
        roots, children_map = build_tree(records)
        print(f"\n根记录: {len(roots)}, 有子记录的父记录: {len(children_map)}")

        chapters = {}
        for root in roots:
            ch = extract_field(root.get("fields", {}), "章节")
            chapters[ch] = chapters.get(ch, 0) + 1
        print(f"章节分布 (根记录): {chapters}")

        # 统计特殊字段
        option_count = sum(1 for r in records if extract_field(r.get("fields", {}), "回应选项"))
        phone_count = sum(1 for r in records if r.get("fields", {}).get("手机", False))
        parent_count = sum(1 for r in records if get_parent_id(r.get("fields", {})))
        print(f"含回应选项: {option_count}, 含手机: {phone_count}, 有父记录: {parent_count}")
        return

    # 构建树
    roots, children_map = build_tree(records)
    print(f"根记录: {len(roots)}, 有子记录的父记录: {len(children_map)}")

    # 统计章节
    chapters = {}
    for root in roots:
        ch = extract_field(root.get("fields", {}), "章节")
        if ch:
            chapters[ch] = chapters.get(ch, 0) + 1
    print(f"\n章节: {chapters}")

    # 确定要导出的章节
    chapter_filter = next((a for a in sys.argv[1:] if not a.startswith("--")), None)

    if chapter_filter:
        chapters_to_export = {chapter_filter: chapters.get(chapter_filter, 0)}
    else:
        chapters_to_export = chapters

    for ch_name, count in chapters_to_export.items():
        print(f"\n[2] 转换章节: {ch_name} ({count} 条根记录)")
        content = convert_chapter(roots, children_map, ch_name)
        filepath = os.path.join(OUTPUT_DIR, f"{ch_name}.dialogue")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  已写入: {filepath}")
        preview = content.split("\n")[:15]
        for line in preview:
            print(f"  | {line}")
        total = len(content.split("\n"))
        if total > 15:
            print(f"  | ... (共 {total} 行)")


if __name__ == "__main__":
    main()
