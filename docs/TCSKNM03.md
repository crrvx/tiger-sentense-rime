# TCSKNM03 五阶分页模型

TCSKNM03 是虎整句 Rime 的纯 Lua 字符五阶模型格式。它用于直接 Beam 搜索，不是三阶候选后的重排层，也不需要 KenLM DLL/SO。

## 设计目标

- 保存完整 1–5 gram backoff 语义，Beam 路径携带最近四个 token。
- 单文件同时提供 observed-bigram 查询，不再为了孤立字先验常驻旧三阶模型。
- 使用 uint16 词 ID；概率与回退权重使用 16-bit 线性量化。
- header 中的量化参数使用整数定点表示，reader 不依赖 string.pack/unpack，兼容 Lua 5.3+ 和 LuaJIT 5.1。
- 2–5 gram 按 context 分块，每 64 个 context 一个稀疏索引点；运行时只读取命中的磁盘页并使用有界缓存。

## 模型语义

正式模型从 Brightmart 纯汉字五阶 ARPA 构建。与虎爪压缩五阶采用相同的 context-vocabulary=128 剪枝规则：

- 1–3 gram 全保留；
- 4/5 gram 只保留历史全部属于 unigram 概率前 128 字（另含特殊符号）的 context；
- 被删除完整分布的 backoff 视为 1，即 log10 backoff 为 0；
- 保留 context 对后缀封闭。

查询从最长可用 history 开始；目标 n-gram 缺失时累加当前 context 的 backoff，再逐级回退，直到 unigram。BOS 进入 history，EOS 正常参与最终评分。

## 文件布局

固定 256-byte header 后是四个 256 项 bucket directory、词表和 2/3/4/5-gram block/index 区。

每个 context block 保存：

1. order-1 个 uint16 context token ID；
2. 一个量化 backoff；
3. successor 数；
4. 按 token ID 排序的 (successor_id, probability)。

bucket 由 context 第一个 token ID 的低 8 bit 选择。每个 bucket 的稀疏索引记录每 64 个 block 的 context 和文件偏移，Lua reader 只加载对应索引和局部 block page。

## 构建与自检

    g++ -std=c++20 -O3 -DNDEBUG tools/build_tcs_knm03.cpp -o build_tcs_knm03
    ./build_tcs_knm03 input.arpa sentence-fivegram-mobile.bin temp-dir
    python3 tools/test_tcs_knm03.py --lua lua
    python3 tools/test_tcs_knm03.py --lua luajit

生产构建必须核对各阶保留记录数、模型 SHA256，并用冻结 20k 形码集与 KenLM 压缩五阶做首选及逐句差异检查。

## 2026-09-22 生产模型与验证

默认生产模型：`sentence-fivegram-mobile.bin`，460,693,519 字节（439.35 MiB），SHA256 `4e6d79b957a55edf35cd9e2e66c62bd0bbe598581b7dc088b462122a713172a7`。转换器从同一份 17 GB 字符五阶 ARPA 流式生成，保留计数逐阶为 21,230 / 7,959,327 / 69,562,625 / 10,273,459 / 8,415,769，与虎爪 compact-fivegram 的剪枝清单完全一致。

冻结 20k 形码集在关闭学习、LLM 与提前上屏的条件下，TCSKNM03 直接 Beam 搜索命中：旧集 9,959 / 10,000，新集 9,971 / 10,000，合计 19,930 / 20,000（99.650%）。虎爪当前 419,929,926 字节 KenLM Q8 compact-fivegram 为 19,926；TCSKNM03 与其只有 5 个首选差异，净多命中 4 句。与此前完整五阶直接搜索的总命中同为 19,930，但逐句并不等价，20k 中有 27 个首选差异，因此不得描述为数值或逐句复刻 KenLM。

Lua 5.4 与 LuaJIT 5.1 均通过 TCSKNM03 fixture、真实模型增量/回删/锁定/提前上屏专项和无模型负控制回归。生产模型分页读取时 8 路并行评测单进程常驻内存约 60 MiB；这只是该次离线进程观测，不作为所有前端的内存承诺。实际 Weasel/fcitx-rime/ibus-rime 前端仍需实机验收。
