# 虎整句 · tiger-sentense-rime

基于虎码（虎整句）码表的 Rime 独立整句输入方案：纯 Lua 变长整句解码，
可选本地 n-gram 语言模型排序，输入行为与 TigerClaw（虎爪）Windows 版对齐。
不依赖任何 Windows 组件，可在小狼毫（Weasel）、Linux ibus-rime/fcitx-rime 等
标准 Rime 前端使用。

## 特性

- 字母连续输入整句编码，空格上屏；变长编码 lattice + Beam 解码。
- 明文码表/字频/白名单（txt），可直接编辑或导入其它形码码表。
- 可选 Kneser-Ney n-gram 语言模型（TCSKNM02 分页格式，Lua 直接读取）；
  无模型时自动降级为「码表名次 → 更少码表边 → 分数」排序。
- 概率型自动提前上屏与空码自动上屏，规则与 TigerClaw Windows 版一致。
- 允许单字重码组句（可开关）：分段路径中的非首选单字按语言模型分数竞争。
- 标点由 `symbols.yaml` 直通上屏；数字后的句号自动输出半角小数点 `.`。

## 安装（小狼毫）

1. 复制本方案全部文件到 Rime 用户目录（Windows 默认
   `%APPDATA%\Rime\`）：`tiger_sentence.schema.yaml`、`lua/`、三个
   `tiger_sentence.*.txt`、`tiger_sentence.supplement.txt`、`symbols.yaml`。
2. 在已有的 `rime.lua` 中合并注册（若没有则直接复制本包的 `rime.lua`）：

   ```lua
   local tiger = require("tiger_sentence")
   tiger_sentence_processor = tiger.processor
   tiger_sentence_translator = tiger.translator
   ```

3. 在已有的 `default.custom.yaml` 的 schema_list 中加入 `tiger_sentence`
   （本包附带示例）。
4. （可选）把 `sentence-ngram-mobile.bin` 放入用户目录 `models/`，
   见下节。
5. 「重新部署」，然后切换到 虎整句。

## 语言模型（可选）

模型文件 `sentence-ngram-mobile.bin`（TCSKNM02，约 224 MiB）从本仓库
Releases 下载，放入用户目录 `models/`。查找顺序：用户目录 `models/` →
用户目录根部 → 共享目录 `models/`。

没有模型时方案完全可用：解码按码表名次优先，整码单字不会被多段拼接
压过，仅失去语言模型排序与提前上屏的置信度计算。

## 数据文件与自定义

全部数据为明文 txt，重新部署即生效，不需要重新生成：

| 文件 | 格式 | 作用 |
| --- | --- | --- |
| `tiger_sentence.codes.txt` | 每行 `字\t编码`，`#` 注释，兼容 CRLF/BOM | 码表；同码内行序即名次，编码仅小写字母（自动小写化） |
| `tiger_sentence.char_ranks.txt` | 每行一个字，行序=频序 | 常用字最优码过滤与生僻字孤立惩罚；缺失时两者禁用 |
| `tiger_sentence.full_code_whitelist.txt` | 白名单字符，每行一个或连排 | 白名单字保留完整编码参与组句 |

- schema 配置 `tiger_sentence/high_freq_limit`（默认 `1500`）：常用字
  （字频前 N）只保留最优码；`0` 全部放开；负数按 `0`。
- schema 配置 `tiger_sentence/min_retained_raw_length`（默认 `0`）：
  自动上屏最少保留编码数，概率型提交仍永远不少于三键。
- 导入其它形码码表：直接替换 `tiger_sentence.codes.txt`（编码仅限拉丁
  字母，单字与多字词均可，行序=选重名次）；想全部保留非最优码时把
  `high_freq_limit` 设为 `0` 并清空白名单。
- `tiger_sentence.supplement.txt`：个人补充语料，每行 `词条 [权重]`，
  默认权重 1000；奖励 `clamp(9 + 2 * ln(weight / 1000), 0, 16)`。
- `symbols.yaml`：标点映射，标量/`commit` 直接上屏，数组映射显示候选。

## 输入行为

- 字母连续输入整句编码；空格提交候选，回车提交原始编码，Esc 清空。
- 有编码时 `;` `'` 数字分别选择码表第 2、3、N 项（`0` 为第 10 项）；
  无编码时由 `symbols.yaml` 输出中文标点。
- 无编码时数字直接上屏（全角开关输出 ０-９，小键盘同）；其后紧邻的
  句号自动输出半角小数点（包括全角数字后），其它标点不受影响。
- Up/Down 或 Tab/Shift+Tab 遍历候选；Tab/Shift+Tab 循环高亮，不立即上屏。
  Tab 高亮后继续输入字母，会锁定该候选的文本和编码边界，后续组句不再跨越
  这个边界重新切分。开启提前上屏时，此次确认立即提交尚未上屏的选中文字；
  关闭时，退格到未提交的锁定边界会解除锁定。Up/Down 本身不触发锁定，
  数字、`;`、`'` 仍用于当前码段选重。
- 一码段只在整段输入只有一码时合法；只有整个输入由单一码表边消费时
  才隐式显示全部名次；非首选多字词在任何切分路径中必须显式选重。
- `允许单字重码组句` 开关（默认开）：分段路径中的非首选单字按语言模型
  分数竞争；`提前上屏` 开关同时控制概率型提前上屏与空码自动上屏。

自动上屏规则与 TigerClaw Windows 版一致：`(文本前缀, raw 边界)` 独立
累计证据，置信阈值 `0.995`、强证据/边界封闭 `0.99999`；截断的候选池
绝不触发高置信空码上屏；提交通过一次原子输入赋值重建 composition，
避免候选窗闪烁。
空码自动上屏的唯一候选分支会额外检查完整码表路径，不把 Beam 裁剪后只剩
一个候选误认为真正唯一；同一文本的不同切分不算不同输出。

## 开发与测试

```bash
# 无模型全量测试（Lua 5.3+；LuaJIT 亦可）
lua tools/test_tiger_sentence_incremental.lua .

# 真实模型全量测试（模型需在查找路径中）
lua tools/test_tiger_sentence_incremental.lua . --require-model

# 解码性能基准
lua tools/bench_tiger_sentence_lua.lua . --mode mobile --repeat 3
```

诊断：Lua 模块导出 `data_status()`（码表/字频/白名单加载状态）与
`performance_status()`（解码耗时、缺页、缓存命中）。

## 来源与许可

本方案是 [TigerClaw（虎爪）输入法](https://github.com/lvyww/tigerclaw)
整句行为的独立 Rime 移植。许可证见 [LICENSE](LICENSE)（GPL-3.0）。
