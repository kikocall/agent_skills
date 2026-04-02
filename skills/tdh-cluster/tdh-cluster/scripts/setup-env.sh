#!/bin/bash
# TDH 环境初始化脚本
# 用法: source setup-env.sh

set -e

TDH_CLIENT_DIR="$HOME/tdh-client/TDH-Client"

if [ ! -d "$TDH_CLIENT_DIR" ]; then
    echo "错误: 找不到 TDH-Client 目录: $TDH_CLIENT_DIR"
    echo "请确保已解压 tdh-client.tar 到 ~/tdh-client/ 目录"
    return 1 2>/dev/null || exit 1
fi

echo "=========================================="
echo "  TDH 环境初始化"
echo "=========================================="
echo ""

# 设置 Kerberos 配置
if [ -f "$TDH_CLIENT_DIR/kerberos/krb5.conf" ]; then
    export KRB5_CONFIG="$TDH_CLIENT_DIR/kerberos/krb5.conf"
    echo "[✓] Kerberos 配置: $KRB5_CONFIG"
else
    echo "[✗] Kerberos 配置文件不存在"
fi

# 运行官方初始化脚本（使用绝对路径，不切换工作目录）
if [ -f "$TDH_CLIENT_DIR/init.sh" ]; then
    echo ""
    echo "运行 TDH 初始化脚本..."
    source "$TDH_CLIENT_DIR/init.sh" n n
else
    echo "[✗] init.sh 脚本不存在"
    return 1 2>/dev/null || exit 1
fi

# 检查 hosts 映射（仅提示，不自动修改系统文件）
echo ""
echo "检查 hosts 映射..."
if ! grep -q "xh13537" /etc/hosts 2>/dev/null; then
    echo "[!] 未检测到集群 hosts 映射，请手动添加以下条目到 /etc/hosts:"
    echo "  172.18.135.37 xh13537"
    echo "  172.18.135.38 xh13538"
    echo "  172.18.135.39 xh13539"
    echo "  执行: sudo bash -c 'echo -e \"172.18.135.37 xh13537\n172.18.135.38 xh13538\n172.18.135.39 xh13539\" >> /etc/hosts'"
else
    echo "[✓] hosts 条目已存在"
fi

# 安装 Kerberos 客户端
echo ""
echo "检查 Kerberos 客户端..."
if command -v kinit &> /dev/null; then
    echo "[✓] Kerberos 客户端已安装"
else
    echo "[✗] Kerberos 客户端未安装"
    echo ""
    echo "请手动安装 Kerberos 客户端:"
    echo "  Ubuntu/Debian: sudo apt-get install -y krb5-user"
    echo "  CentOS/RHEL: sudo yum install -y krb5-workstation"
    echo "  macOS: brew install krb5"
fi

# 检查 Kerberos 系统配置（仅提示，不自动修改系统文件）
echo ""
echo "检查 Kerberos 系统配置..."
if [ -f "$TDH_CLIENT_DIR/kerberos/krb5.conf" ]; then
    if [ -f /etc/krb5.conf ]; then
        if ! diff -q "$TDH_CLIENT_DIR/kerberos/krb5.conf" /etc/krb5.conf &> /dev/null; then
            echo "[!] /etc/krb5.conf 与 TDH 配置不一致，请手动更新:"
            echo "  sudo cp $TDH_CLIENT_DIR/kerberos/krb5.conf /etc/krb5.conf"
        else
            echo "[✓] /etc/krb5.conf 已是最新的"
        fi
    else
        echo "[!] /etc/krb5.conf 不存在，请手动创建:"
        echo "  sudo cp $TDH_CLIENT_DIR/kerberos/krb5.conf /etc/krb5.conf"
    fi
else
    echo "[!] TDH Kerberos 配置文件不存在"
fi

echo ""
echo "=========================================="
echo "  环境初始化完成"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 获取 Kerberos 票据: kinit username@TDHXH"
echo "  2. 测试 HDFS: hdfs dfs -ls /"
echo "  3. 测试 Hive: beeline -u 'jdbc:hive2://xh13537:10000/default;principal=hive/_HOST@TDHXH'"
echo ""
echo "集群信息:"
echo "  Manager: https://172.18.135.39:8180"
echo "  HDFS: hdfs://nameservice1"
echo "  Kerberos Realm: TDHXH"
echo "  KDC: xh13537:1088, xh13539:1088"
echo ""
