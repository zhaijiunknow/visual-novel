import requests
import os
import sys
import json
import re
from pathlib import Path
from datetime import datetime, timezone, timedelta
from collections import defaultdict

BEIJING_TZ = timezone(timedelta(hours=8))
from feishu_auth import get_tenant_token, APP_TOKEN

sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent

PERFORMANCE_TABLE_ID = "tblCjPtCWMLcKCS7"  # 演出表
BASE_URL = "https://open.feishu.cn/open-apis"
OUTPUT_DIR = REPO_ROOT / "dialogue_manager" / "dialogues"
PREPARE_BACKGROUND_PATTERN = re.compile(r"^\$>\s*PrepareBackground\s*\(")
NO_PORTRAIT_CHARACTERS = {"周腾"}


def prepares_background(command):
    return bool(PREPARE_BACKGROUND_PATTERN.match(command.strip()))


def has_portrait(character):
    return bool(character) and character not in NO_PORTRAIT_CHARACTERS

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


def parse_duration(value):
    value = str(value or "").strip()
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def format_duration(value):
    return f"{value:g}"


def _append_multi_value(values, value):
    if value is None or value is False:
        return
    if isinstance(value, str):
        value = value.strip()
        if value:
            values.append(value)
        return
    if isinstance(value, (int, float)):
        values.append(str(value))
        return
    if isinstance(value, list):
        for item in value:
            _append_multi_value(values, item)
        return
    if isinstance(value, dict):
        for key in ("text", "name", "value", "text_arr"):
            if key in value:
                _append_multi_value(values, value[key])
                return


def extract_multi_values(fields, name):
    """提取多选字段值，返回去重后的字符串数组。"""
    values = []
    _append_multi_value(values, fields.get(name))

    unique_values = []
    seen = set()
    for value in values:
        if value not in seen:
            unique_values.append(value)
            seen.add(value)
    return unique_values


def _split_portrait_value(value):
    """允许多选字段，也兼容逗号/换行分隔的文本字段。"""
    if not isinstance(value, str):
        return []
    parts = re.split(r"[,，\n\r]+", value)
    return [part.strip() for part in parts if part.strip()]


def extract_portrait_actions(fields, name, character):
    """提取立绘操作角色；布尔 true 表示当前行角色，多选/文本表示指定角色。"""
    val = fields.get(name)
    if val is True:
        return [character] if character else []
    if val is False or val is None:
        return []
    values = []
    for value in extract_multi_values(fields, name):
        split_values = _split_portrait_value(value)
        values.extend(split_values if split_values else [value])

    unique_values = []
    seen = set()
    for value in values:
        if value not in seen:
            unique_values.append(value)
            seen.add(value)
    return unique_values


def add_visible_character(state, character):
    state["visible_characters"].add(character)
    if character not in state["visible_character_order"]:
        state["visible_character_order"].append(character)


def remove_visible_character(state, character):
    state["visible_characters"].remove(character)
    if character in state["visible_character_order"]:
        state["visible_character_order"].remove(character)


def append_fade_in(lines, tabs, state, character, body=None, expression=None):
    if has_portrait(character) and character not in state["visible_characters"]:
        # 优先用传入的 body，其次用 state 中追踪的身体
        effective_body = body if (body and body != "-") else state.get("character_bodies", {}).get(character, "")
        if effective_body:
            lines.append(f'{tabs}$> Character("{character}").SetBody("{effective_body}")')
        # 优先用传入的 expression，其次用 state 中追踪的表情
        effective_expression = expression if (expression and expression != "-") else state.get("character_expressions", {}).get(character, "")
        if effective_expression:
            lines.append(f'{tabs}$> Character("{character}").SetExpression("{effective_expression}")')
        lines.append(f'{tabs}$> Character("{character}").FadeIn("Center")')
        add_visible_character(state, character)


def append_fade_out(lines, tabs, state, character):
    if has_portrait(character) and character in state["visible_characters"]:
        lines.append(f'{tabs}$> Character("{character}").FadeOut()')
        remove_visible_character(state, character)


def _sync_optionals(lines, tabs, state, character, new_optionals):
    """比较角色上一句与当前行的附加部件，附加从有→无时生成 ClearOptionals。

    引擎侧（stage_page.gd）只在有 #附加 tag 时才 Clear+Set，没有 tag 就什么都不做，
    所以上一句设过的部件（如眼镜）会一直残留。当前行没有附加时必须显式清除。
    换一组附加（两段都不为空）：行上的 #附加 tag 会先 Clear 再 Set，无需额外指令。
    """
    new_list = list(new_optionals) if new_optionals else []
    prev = state["character_optionals"].get(character)
    state["character_optionals"][character] = new_list
    if prev and not new_list:
        lines.append(f'{tabs}$> Character("{character}").ClearOptionals()')


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


def record_to_data(record):
    """将一条演出表记录转换为结构化数据"""
    fields = record.get("fields", {})
    character = extract_field(fields, "角色")
    costume = extract_field(fields, "服装")
    action = extract_field(fields, "动作")
    body = f"{costume}-{action}" if costume and action else ""

    optionals_raw = fields.get("附加", [])
    if isinstance(optionals_raw, list):
        optionals = [str(item) for item in optionals_raw if item]
    else:
        optionals = []

    return {
        "sheet_id": extract_field(fields, "ID").strip(),
        "feishu_record_id": record.get("record_id", "") or record.get("recordId", ""),
        "character": character,
        "text": extract_field(fields, "文字"),
        "is_option": fields.get("选项", False),
        "hidden": fields.get("隐藏", False),
        "voice": extract_field(fields, "语音"),
        "nickname": extract_field(fields, "昵称"),
        "hide_avatar": fields.get("隐藏头像", False),
        "entering_portraits": extract_portrait_actions(fields, "立绘入场", character) + extract_portrait_actions(fields, "显示立绘", character),
        "hidden_portraits": extract_portrait_actions(fields, "隐藏立绘", character),
        "body": body,
        "expression": extract_field(fields, "表情"),
        "end_expression": extract_field(fields, "结束表情"),
        "optionals": optionals,
        "phone": fields.get("手机", False),
        "book": fields.get("奇迹书", False),
        "delay": extract_field(fields, "延迟"),
        "bg_name": extract_field(fields, "场景"),
        "time_period": extract_field(fields, "时段"),
        "bg_fade_to_black": extract_field(fields, "黑屏淡入"),
        "bg_fade_from_black": extract_field(fields, "黑屏淡出"),
        "date": extract_field(fields, "日期"),
        "week_day": extract_field(fields, "星期"),
        "time": extract_field(fields, "时间"),
        "chapter": extract_field(fields, "章节"),
        "music": extract_field(fields, "音乐"),
        "commands": extract_field(fields, "指令"),
        "cg_name": extract_field(fields, "CG"),
        "cg_variation": extract_field(fields, "CG差分"),
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
    if data["book"]:
        tags.append("#奇迹书")
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
    if data["end_expression"] and data["end_expression"] != "-":
        tags.append(f"#结束表情={data['end_expression']}")
    if data["optionals"]:
        tags.append(f"#附加={','.join(data['optionals'])}")
    return f"[{', '.join(tags)}]" if tags else ""


def sanitize_static_id(raw):
    value = (raw or "").strip()
    if not value:
        return ""
    value = re.sub(r"\s+", "_", value)
    value = re.sub(r"[^A-Za-z0-9._-]", "_", value)
    return value.strip("._-")


def build_static_id(data, state, kind):
    base = sanitize_static_id(data.get("sheet_id", ""))
    if not base:
        base = sanitize_static_id(data.get("feishu_record_id", ""))
    if not base:
        state["fallback_id_counter"] += 1
        base = sanitize_static_id(f"{state['chapter_name']}_{kind}_{state['fallback_id_counter']:04d}")
    candidate = f"{base}.{kind}"
    final_id = candidate
    suffix = 2
    while final_id in state["used_static_ids"]:
        final_id = f"{candidate}_{suffix}"
        suffix += 1
    state["used_static_ids"].add(final_id)
    return final_id


def build_dialogue_line(data, static_id):
    """构建一行 dialogue 格式的文本（不含缩进）"""
    character = data["character"]
    text = data["text"]

    if not character and not text:
        return None

    tag_str = build_tags(data)
    id_suffix = f" [ID:{static_id}]"

    if character:
        return f"{character}: {tag_str}{text}{id_suffix}"
    else:
        return f"独白: {text}{id_suffix}"


def generate_do_commands(data, state, lines, tabs):
    """生成 do 指令行（背景切换、FadeIn、ShowPhone/HidePhone）"""

    if data["bg_name"] and data["time_period"]:
        if data["bg_name"] != state["bg_name"] or data["time_period"] != state["time_period"]:
            if state["skip_next_set_background"]:
                state["skip_next_set_background"] = False
            else:
                fade_to_black = parse_duration(data.get("bg_fade_to_black", ""))
                fade_from_black = parse_duration(data.get("bg_fade_from_black", ""))
                if fade_to_black is not None or fade_from_black is not None:
                    default_duration = 0.0 if not state["bg_name"] else 1.2
                    out_time = fade_to_black if fade_to_black is not None else default_duration
                    in_time = fade_from_black if fade_from_black is not None else default_duration
                    lines.append(
                        f'{tabs}$> SetBackground("{data["bg_name"]}", "{data["time_period"]}", '
                        f'{format_duration(out_time)}, {format_duration(in_time)})'
                    )
                elif not state["bg_name"]:
                    lines.append(f'{tabs}$> SetBackground("{data["bg_name"]}", "{data["time_period"]}", 0, 0)')
                else:
                    lines.append(f'{tabs}$> SetBackground("{data["bg_name"]}", "{data["time_period"]}")')
            state["bg_name"] = data["bg_name"]
            state["time_period"] = data["time_period"]
            state["visible_characters"].clear()
            state["visible_character_order"].clear()

    cg_key = ""
    if data["cg_name"] and data["cg_variation"]:
        cg_key = f'{data["cg_name"]}-{data["cg_variation"]}'
    if cg_key != state.get("cg_key", ""):
        if cg_key:
            lines.append(f'{tabs}$> SetCG("{data["cg_name"]}", "{data["cg_variation"]}")')
        else:
            lines.append(f"{tabs}$> HideCG()")
        state["cg_key"] = cg_key

    if data["music"] != state["music"]:
        if data["music"]:
            lines.append(f'{tabs}$> SetMusic("{data["music"]}")')
        else:
            lines.append(f'{tabs}$> StopMusic()')
        state["music"] = data["music"]

    hidden_portraits = data.get("hidden_portraits", [])
    if data["date"] and data["week_day"]:
        date_key = f'{data["date"]}-{data["week_day"]}-{data["time"]}'
        if date_key != state["date_key"]:
            restore_characters = state["visible_character_order"].copy()
            lines.append(f"{tabs}$> HideDialogue()")
            for visible_character in state["visible_character_order"]:
                lines.append(f'{tabs}$> Character("{visible_character}").FadeOut()')
            state["visible_characters"].clear()
            state["visible_character_order"].clear()

            timestamp_ms = int(float(data["date"]))
            dt = datetime.fromtimestamp(timestamp_ms / 1000, tz=BEIJING_TZ)
            month = dt.month
            day = dt.day
            week_day = data["week_day"] + data["time"]
            lines.append(f'{tabs}$> SetDate({month}, {day}, "{week_day}")')

            for visible_character in restore_characters:
                append_fade_in(lines, tabs, state, visible_character)
            lines.append(f"{tabs}$> ShowDialogue()")
            state["date_key"] = date_key

    is_phone = bool(data["phone"])
    if is_phone and not state["phone_mode"]:
        lines.append(f"{tabs}$> ShowPhone()")
        state["phone_mode"] = True
    elif not is_phone and state["phone_mode"]:
        lines.append(f"{tabs}$> wait(2)")
        lines.append(f"{tabs}$> HidePhone()")
        state["phone_mode"] = False

    if data["commands"]:
        for cmd_line in data["commands"].split("\n"):
            cmd_line = cmd_line.strip()
            if cmd_line:
                lines.append(f"{tabs}{cmd_line}")
                if prepares_background(cmd_line):
                    state["skip_next_set_background"] = True

    # 追踪角色身体/表情（在 FadeIn 之前记录）
    character = data["character"]
    if data["body"] and data["body"] != "-" and character:
        state["character_bodies"][character] = data["body"]
    if data["expression"] and data["expression"] != "-" and character:
        state["character_expressions"][character] = data["expression"]

    # 追踪附加部件：当前行没有附加但上一句有 → 显式 ClearOptionals。
    # 放在 FadeIn 之前，避免角色回归时先带着旧部件闪一下再被清除
    if character and has_portrait(character):
        _sync_optionals(lines, tabs, state, character, data["optionals"])

    for entering_character in data.get("entering_portraits", []):
        append_fade_in(lines, tabs, state, entering_character)

    if has_portrait(character) and character not in hidden_portraits and not data["phone"] and character not in state["visible_characters"]:
        append_fade_in(lines, tabs, state, character, data.get("body", ""), data.get("expression", ""))


def generate_after_dialogue_commands(data, state, lines, tabs):
    """生成对白后的指令行。"""
    for hidden_character in data.get("hidden_portraits", []):
        append_fade_out(lines, tabs, state, hidden_character)


def _close_book_if_needed(state, lines, tabs=""):
    if state.get("book_mode", False):
        state["book_mode"] = False


def _open_book_if_needed(state, lines, tabs=""):
    if not state.get("book_mode", False):
        lines.append(f"{tabs}$> OpenBook()")
        state["book_mode"] = True


# ─── 递归遍历 ───

def walk(record, children_map, indent, lines, state):
    """递归遍历记录树，生成 dialogue 文件内容"""
    data = record_to_data(record)
    children = children_map.get(record["record_id"], [])
    tabs = "\t" * indent

    if data["hidden"]:
        for child in children:
            walk(child, children_map, indent, lines, state)
        return

    if data["is_option"]:
        option_id = build_static_id(data, state, "opt")
        lines.append(f"{tabs}- {data['text']} [ID:{option_id}]")
        for child in children:
            walk(child, children_map, indent + 1, lines, state)
    elif data["book"]:
        generate_do_commands(data, state, lines, tabs)
        _open_book_if_needed(state, lines, tabs)
        dialogue_id = build_static_id(data, state, "line")
        dialogue_line = build_dialogue_line(data, dialogue_id)
        if dialogue_line:
            lines.append(f"{tabs}{dialogue_line}")
        generate_after_dialogue_commands(data, state, lines, tabs)
        for child in children:
            walk(child, children_map, indent, lines, state)
    else:
        _close_book_if_needed(state, lines, tabs)
        generate_do_commands(data, state, lines, tabs)
        dialogue_id = build_static_id(data, state, "line")
        dialogue_line = build_dialogue_line(data, dialogue_id)
        if dialogue_line:
            lines.append(f"{tabs}{dialogue_line}")
        generate_after_dialogue_commands(data, state, lines, tabs)
        for child in children:
            walk(child, children_map, indent, lines, state)


# ─── 章节导出 ───

def convert_chapter(roots, children_map, chapter_filter):
    """将指定章节的记录树转换为 dialogue 文件内容"""
    lines = ["~ start"]
    state = {
        "visible_characters": set(),
        "visible_character_order": [],
        "character_bodies": {},
        "character_expressions": {},
        "character_optionals": {},
        "bg_name": "",
        "time_period": "",
        "date_key": "",
        "phone_mode": False,
        "book_mode": False,
        "skip_next_set_background": False,
        "music": "",
        "used_static_ids": set(),
        "fallback_id_counter": 0,
        "chapter_name": chapter_filter,
    }

    current_chapter = None
    for root in roots:
        data = record_to_data(root)
        if data["chapter"]:
            current_chapter = data["chapter"]
        if current_chapter != chapter_filter:
            continue
        walk(root, children_map, 0, lines, state)

    if state["phone_mode"]:
        lines.append("$> wait(2)")
        lines.append("$> HidePhone()")
    _close_book_if_needed(state, lines)

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

    if "--dump" in sys.argv:
        print("\n[DUMP] 前 5 条记录:")
        for i, record in enumerate(records[:5]):
            fields = record.get("fields", {})
            print(f"\n--- 记录 {i+1} (id={record.get('record_id', '?')}) ---")
            for k, v in fields.items():
                print(f"  {k}: {repr(v)}")

        roots, children_map = build_tree(records)
        print(f"\n根记录: {len(roots)}, 有子记录的父记录: {len(children_map)}")

        chapters = {}
        for root in roots:
            ch = extract_field(root.get("fields", {}), "章节")
            chapters[ch] = chapters.get(ch, 0) + 1
        print(f"章节分布 (根记录): {chapters}")

        option_count = sum(1 for r in records if r.get("fields", {}).get("选项", False))
        phone_count = sum(1 for r in records if r.get("fields", {}).get("手机", False))
        parent_count = sum(1 for r in records if get_parent_id(r.get("fields", {})))
        print(f"含选项: {option_count}, 含手机: {phone_count}, 有父记录: {parent_count}")
        return

    roots, children_map = build_tree(records)
    print(f"根记录: {len(roots)}, 有子记录的父记录: {len(children_map)}")

    chapters = {}
    for root in roots:
        ch = extract_field(root.get("fields", {}), "章节")
        if ch:
            chapters[ch] = chapters.get(ch, 0) + 1
    print(f"\n章节: {chapters}")

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
