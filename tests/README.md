# 回归测试

无第三方框架（不引 GUT / gdUnit），一个脚本 + 一个场景，headless 直跑，退出码给 CI 用。

## 跑法

```powershell
# 全部用例（约 3 秒）
D:\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe `
  --headless --path D:\Unity\Project\visual-novel res://tests/regression_test.tscn
```

- 全绿：stdout 末尾 `结果：通过 N，失败 0`，**退出码 0**
- 有失败：打印 `FAIL xxx`，**退出码 1**

> 注意：别用 `cmd /c "... & echo %ERRORLEVEL%"` 取退出码 —— `%ERRORLEVEL%` 会在整行解析时提前展开，
> 拿到的永远是上一次的值（我自己踩过这个坑）。PowerShell 里直接 `& <exe> ...; $LASTEXITCODE`。

跑测试会先起全部 autoload（Main / Game / AudioManager / Diagnostic…），所以日志里出现
`[Game] switch_to_page page=MainMenu` 之类是正常的；测试本身只碰 `user://tests_tmp/`，
跑完自己删干净，不碰玩家真实存档。

## 覆盖的是什么

对应 2026-10 那次线上崩溃（玩家设置文件被写成半截 → 每次启动 0xC0000005）：

| 用例 | 钉住的实现 / 不变量 |
|------|--------------------|
| 文件不存在 | `Main._read_resource()` 返回 null，不凭空造文件 |
| 正常存档 | 正常读出，不产生 `.bad`，文件留在原位 |
| **半截（写坏的）存档** | 返回 null（不是坏对象）+ 备份成 `.bad`（逐字节一致）+ 从原位挪走（否则每次启动都读同一个坏档） |
| 原子写盘 | 正式文件可读、没有 `.tmp.tres` 残留 |
| 残留 `.tmp.tres` | 上次崩在写 tmp 的半路，不影响下一次保存 |
| 写 null | 返回 `ERR_INVALID_PARAMETER`，**已有文件一个字节都不动** |
| **`setting_data == null` 时生成快照** | 不崩、非空、明确写出"设置读取失败"（线上崩的就是这里） |
| **`setting_data == null` 时打整包** | zip 能生成，包里 `environment.txt` 非空（线上是 0 字节，等于没有现场） |
| `setting_data` 正常时生成快照 | 兜底分支不会吞掉正常输出（数值该有都有） |

反向验证过：把 `diagnostic_bundle.gd` 的 null 兜底退回旧写法，这套用例会变成
`通过 34，失败 7`、退出码 1 —— 它确实抓得住这次回归，不是装饰。

## 故意没覆盖的

**冷启动读坏档**（把 `user://setting_data.tres` 截断后重新启动）没法在同一个进程里测：
`Main._ready()` 在测试场景之前就跑完了。它靠上面两个"拆开的"不变量间接保证
（读档返回 null 不污染全局 + 快照对 null 安全），完整链路请按下面手动过一遍。

### 手动 e2e（发版前 / 改动涉及 `Main._ready` 或 Diagnostic 时）

```powershell
$test = "$env:APPDATA\Godot\app_userdata\无言初雪与奇迹书"   # 编辑器/Debug 包；Release 包是 %APPDATA%\无言初雪与奇迹书
Copy-Item "$test\setting_data.tres" "$env:TEMP\bak.tres"     # 1) 先备份
$b = [System.IO.File]::ReadAllBytes("$test\setting_data.tres")[0..59]
[System.IO.File]::WriteAllBytes("$test\setting_data.tres", $b)   # 2) 截成半截
Set-Content "$test\diagnostics\run.lock" '{"pid":1}'             # 3) 伪造"上次异常退出"
# 4) 启动游戏 —— 预期：进主菜单、不崩；$test 下出现 setting_data.tres.bad，原文件消失
# 5) 再启动一次 —— 预期：完全正常（坏档自愈，不再连环崩）
Copy-Item "$env:TEMP\bak.tres" "$test\setting_data.tres" -Force  # 6) 还原
```

2026-10-25 已按这个流程在导出包上验证过：修复前 10 秒内 0xC0000005，修复后跑满 30 秒正常、
坏档被切成 `.bad`、崩溃日志包正常导出且 `environment.txt` 有内容。
