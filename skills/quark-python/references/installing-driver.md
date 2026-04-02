# Installing The Quark Driver From This Skill

这个 skill 自带 Quark Python 驱动安装包，方便迁移到其他项目或工具后快速使用。

## Wheel 路径

随 skill 一起保存的文件：

- `assets/quark_python-0.0.1-py2.py3-none-any.whl`

如果 skill 安装在默认 Codex 目录，完整路径通常是：

- `C:\Users\Administrator\.codex\skills\quark-python\assets\quark_python-0.0.1-py2.py3-none-any.whl`

实际使用时，优先基于“当前 skill 目录”去定位，不要把用户机器上的绝对路径写死到代码里。

## 推荐安装方式

### Windows

如果使用 `py`：

```powershell
py -m pip install "C:\Users\Administrator\.codex\skills\quark-python\assets\quark_python-0.0.1-py2.py3-none-any.whl"
```

如果使用 `python`：

```powershell
python -m pip install "C:\Users\Administrator\.codex\skills\quark-python\assets\quark_python-0.0.1-py2.py3-none-any.whl"
```

### Linux / macOS

把 skill 迁移过去后，按 skill 实际目录安装，例如：

```bash
python3 -m pip install ~/.codex/skills/quark-python/assets/quark_python-0.0.1-py2.py3-none-any.whl
```

## 常见附加依赖

根据任务情况，再补这些包：

```bash
pip install pandas thrift thrift_sasl six bitarray
```

Kerberos 场景：

- Windows：关注 `winkerberos`
- Linux/macOS：关注 `kerberos` 或系统 Kerberos 库，以及 `krbcontext`

例如：

```bash
pip install krbcontext
```

## Skill 使用规则

当需要连接 Quark 且环境中没有安装 `quark_python` 时：

1. 先检查当前 Python 命令可用性
2. 再检查 skill 自带 wheel 是否存在
3. 优先给出从 skill 自带 wheel 安装的命令
4. 真正执行安装前，先向用户确认

## 迁移到其他项目或工具时

如果把整个 `quark-python` skill 文件夹复制到其他环境，只要保留：

- `SKILL.md`
- `references/`
- `assets/quark_python-0.0.1-py2.py3-none-any.whl`

就仍然可以快速使用。

推荐迁移后先做两步：

1. 确认 wheel 路径存在
2. 用目标环境的 Python 执行 `-m pip install <wheel-path>`
