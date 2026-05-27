# Python 更新脚本风险 / 可用性检查清单

本文档检查 `python/` 目录下的更新脚本，关注以下问题：
- `.env` 加载是否稳定
- 路径是否依赖本机绝对路径
- 是否支持安全预演（dry-run / confirm）
- 是否存在字段类型假设风险
- 是否可能覆盖或误更新飞书数据

检查对象：
- `python/update_voices.py`
- `python/update_matched_voices.py`
- `python/update_galleries_in_feishu.py`
- `python/update_backgrounds_in_feishu.py`
- `python/update_bodies.py`

---

## 总体结论

优先级从高到低：

1. **高优先级修复**
   - 把所有 `load_dotenv("feishu.env")` 改成基于脚本目录加载
   - 把所有硬编码绝对路径改成相对 `__file__` 的路径
   - 给所有 `get_tenant_token()` 增加失败时的明确报错输出

2. **中优先级修复**
   - 给会写飞书的脚本增加 `--dry-run` 或确认步骤
   - 检查飞书字段类型假设，避免单选/关联/富文本误写
   - 避免整条 record 覆盖式更新，优先只 PATCH 需要变更的字段

3. **低优先级修复**
   - 统一日志格式
   - 清理未使用函数、注释代码和重复逻辑

---

## 1. update_voices.py

文件： [python/update_voices.py](python/update_voices.py)

### 作用
- 扫描 `assets/voice`
- 从飞书演出表抓取记录
- 按角色名 + 台词文本匹配语音文件
- 把匹配结果写回演出表的 `语音` 字段

### 优点
- 支持 `--dry-run`，相对安全
- 会先打印字段结构和匹配结果，再执行更新
- 自动检测字段名，兼容性比其他脚本更好

### 风险 / 问题
1. `.env` 加载不稳定
   - 使用 `load_dotenv("feishu.env")`
   - 如果运行时 cwd 不是 `python/`，可能读不到环境变量

2. 路径是硬编码绝对路径
   - `VOICE_DIR = r"E:\Unity\visual-novel\assets\voice"`
   - 换机器或换目录就失效

3. `get_tenant_token()` 依赖 `feishu_auth.py`
   - 如果 `feishu_auth.py` 仍然直接取 `resp.json()["tenant_access_token"]`，报错信息不够友好

4. 字段自动识别可能误判
   - `角色字段/台词字段/语音字段` 是通过名字猜测的
   - 如果飞书字段命名变化，可能匹配到错误字段

### 建议
- 优先保留，这个脚本整体是最可用的一支
- 先修 `.env` 和 `VOICE_DIR`
- 再考虑把自动字段识别改成“自动识别 + 手动覆盖参数”

### 评级
- **可用性：高**
- **风险：中**

---

## 2. update_matched_voices.py

文件： [python/update_matched_voices.py](python/update_matched_voices.py)

### 作用
- 使用内置 `MATCHES` 字典
- 直接把人工确认好的匹配结果写回演出表的 `语音` 字段

### 优点
- 有确认步骤：执行前会 `input("确认更新? (y/n): ")`
- 支持 `--dry-run`
- 适合处理自动匹配没覆盖到的尾部数据

### 风险 / 问题
1. `.env` 加载不稳定
   - 同样使用 `load_dotenv("feishu.env")`

2. 依赖硬编码本地文件
   - 读取 `E:/Unity/visual-novel/python/matching_data.json`
   - 换机器即失效

3. 数据是脚本内硬编码的
   - `MATCHES` 和 `UNMATCHED` 都写死在文件里
   - 长期维护容易过时

4. 只适用于“余洛琛”前缀
   - `voice_value = f"余洛琛/{voice_filename}"`
   - 不是通用脚本

### 建议
- 保留为“人工补丁脚本”
- 不建议当成常规同步脚本
- 建议把 `matching_data.json` 路径改为相对路径

### 评级
- **可用性：中**
- **风险：中**

---

## 3. update_galleries_in_feishu.py

文件： [python/update_galleries_in_feishu.py](python/update_galleries_in_feishu.py)

### 作用
- 扫描 `data/galleries/*.tres`
- 提取 CG 名称和差分图片名
- 同步到飞书 CG 表

### 优点
- 本地资源路径已经改成相对路径：
  - `Path(__file__).parent.parent / "data" / "galleries"`
- 分页获取飞书记录，规模适应性较好
- 已存在则更新，不存在则创建，逻辑清晰

### 风险 / 问题
1. `.env` 加载不稳定
   - 仍然是 `load_dotenv("feishu.env")`

2. `update_record()` 使用 `PUT`
   - 脚本注释里已经意识到 `PUT 会覆盖整个 record`
   - 当前通过合并 `existing_fields` 规避，但仍然较脆弱
   - 如果飞书返回字段格式和提交格式不完全一致，可能出问题

3. `id/path` 解析里有明显 bug
   - 这一段：
     - [python/update_galleries_in_feishu.py:36-37](python/update_galleries_in_feishu.py#L36-L37)
   - `id_to_path[m.group(2)] = m.group(1)` 看起来把 path 和 id 写反了
   - 在部分 `.tres` 文件顺序下可能导致差分解析错误

### 建议
- 这是值得优先修的一支
- 先修 `.env`
- 再检查 ext_resource 解析逻辑
- 最好把更新方式从 `PUT` 改成更小范围的更新

### 评级
- **可用性：中高**
- **风险：中高**

---

## 4. update_backgrounds_in_feishu.py

文件： [python/update_backgrounds_in_feishu.py](python/update_backgrounds_in_feishu.py)

### 作用
- 扫描背景 `.tres`
- 提取名称和时段
- 同步到飞书背景表

### 优点
- 逻辑清楚：查记录、匹配名称、更新或创建
- 使用 `PATCH` 更新，比 `PUT` 更稳

### 风险 / 问题
1. `.env` 加载不稳定
   - 仍然是 `load_dotenv("feishu.env")`

2. 背景目录是硬编码绝对路径
   - `Path("E:/Unity/visual-novel/data/backgrounds")`
   - 换机器会失效

3. `get_tenant_token()` 失败信息不友好
   - 直接 `resp.json()["tenant_access_token"]`
   - 凭据错时只会抛 KeyError

4. 更新时复制整份 `existing_fields`
   - 虽然是 `PATCH`，但仍把完整 `fields` 提交回去
   - 如果某些字段是只读/特殊类型，可能引发问题

### 建议
- 很适合修成稳定脚本
- 优先改 `.env`、背景目录、token 报错
- 之后只提交 `{"时段": ...}` 这类最小更新字段

### 评级
- **可用性：中**
- **风险：中**

---

## 5. update_bodies.py

文件： [python/update_bodies.py](python/update_bodies.py)

### 作用
- 扫描 `characters/instances/*.tscn`
- 提取动画名
- 解析成“服装 / 动作”
- 写入飞书动作表

### 优点
- 功能目标明确
- 逻辑简单直观

### 风险 / 问题
1. 脚本当前可用性最差
   - 引入了 `get_tenant_token`，但没有引入 `APP_TOKEN`
   - [python/update_bodies.py:31](python/update_bodies.py#L31)、[python/update_bodies.py:109-113](python/update_bodies.py#L109-L113) 等位置使用 `APP_TOKEN`，会直接报错

2. `.env` 加载不稳定
   - 仍然是 `load_dotenv("feishu.env")`

3. 使用硬编码绝对路径
   - `CHARACTERS_DIR = r"E:\Unity\visual-novel\characters\instances"`

4. 字段类型假设风险高
   - 当前写入：`{"角色": [character_id], "服装": costume, "动作": action}`
   - 但你前面已经遇到过类似字段类型误判的问题

5. 存在大量测试/废弃逻辑
   - `test()` 中引用了不存在或不一致的变量，如 `ACTION_TABLE_ID`
   - 说明脚本状态偏实验性

6. `find_character_id()` 每次都重新请求 token / 查询远端
   - 性能低，也不稳定

### 建议
- 这支脚本需要重构后再用
- 不建议直接作为日常同步脚本运行
- 如果继续保留，应先：
  1. 修 APP_TOKEN 来源
  2. 确认动作表字段类型
  3. 清理 test / dead code
  4. 缓存角色映射

### 评级
- **可用性：低**
- **风险：高**

---

## 统一修复建议

### 第一批建议立刻修
1. `load_dotenv(Path(__file__).with_name("feishu.env"))`
2. 所有本地资源目录改成基于 `Path(__file__)` 的相对路径
3. 所有 `get_tenant_token()` 改成：
   - 读取 `resp.json()`
   - 没拿到 token 时抛出带返回内容的错误

### 第二批建议
4. 给所有更新脚本增加 `--dry-run`
5. 对写飞书的脚本增加“更新前打印变更摘要”
6. 优先最小字段更新，避免回传整份 `existing_fields`

### 第三批建议
7. 提取公共工具到 `python/feishu_auth.py` / `python/feishu_utils.py`
8. 统一日志与参数风格
9. 清理 `update_bodies.py` 的实验性代码

---

## 推荐使用顺序

如果现在就要用，建议优先级：

1. `update_voices.py` — 最成熟
2. `update_matched_voices.py` — 适合人工补录
3. `update_backgrounds_in_feishu.py` — 修完路径后可用
4. `update_galleries_in_feishu.py` — 修完解析/PUT 风险后可用
5. `update_bodies.py` — 需要先修，不建议直接跑
