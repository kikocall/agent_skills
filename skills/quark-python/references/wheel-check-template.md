# Wheel Check Template

当检测到当前环境尚未安装 `quark_python`，但 skill 自带 wheel 存在时，优先按这个模板与用户沟通。

## 标准流程

### 情况 1：Python 可用，wheel 存在，但驱动未安装

按以下结构输出：

```text
我检查了当前环境：
- Python：可用
- quark_python：未安装
- skill 自带安装包：已找到

可以直接从这个 skill 自带的 wheel 安装：
<安装命令>

如果你确认，我再执行安装。
```

### Windows 安装命令模板

优先 `py`：

```powershell
py -m pip install "<skill-path>\\assets\\quark_python-0.0.1-py2.py3-none-any.whl"
```

如果系统里只有 `python`：

```powershell
python -m pip install "<skill-path>\\assets\\quark_python-0.0.1-py2.py3-none-any.whl"
```

### Linux / macOS 安装命令模板

```bash
python3 -m pip install <skill-path>/assets/quark_python-0.0.1-py2.py3-none-any.whl
```

## 标准补充说明

如果任务依赖 `pandas` 或 Kerberos，再追加一句：

```text
另外，这个任务可能还需要补装 `pandas`、`krbcontext` 或 Kerberos 相关依赖，我会在连接前继续帮你检查。
```

## 情况 2：Python 不可用

按以下结构输出：

```text
我检查了当前环境：
- Python：未找到可用解释器
- quark_python：无法检测
- skill 自带安装包：已找到

在安装这个 wheel 前，需要先确认当前机器可用的 Python 命令或先安装 Python。
```

## 情况 3：wheel 不存在

按以下结构输出：

```text
我检查了当前环境：
- Python：可用
- quark_python：未安装
- skill 自带安装包：未找到

当前这个 skill 里没有可直接安装的 wheel。你可以提供驱动包，或让我按其他来源继续处理。
```

## 使用要求

- 输出检测结果时尽量短，不要把一大堆环境日志直接贴给用户
- 必须给出明确的下一步动作
- 真正执行安装前仍然要用户确认
