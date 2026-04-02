#!/bin/bash

TDH_CLIENT="${TDH_CLIENT:-$HOME/TDH-Client}"
pass=0
fail=0
warn=0

check_pass() { echo "  [✓] $1"; ((pass++)); }
check_fail() { echo "  [✗] $1"; ((fail++)); }
check_warn() { echo "  [!] $1"; ((warn++)); }

echo "=========================================="
echo "  TDH 环境检查"
echo "=========================================="
echo ""

echo "[1] Java 环境"
if command -v java &> /dev/null; then
    version=$(java -version 2>&1 | head -1 | grep -oP '"\K[^"]+')
    major=$(echo "$version" | cut -d. -f1)
    if [ "$major" -ge 1 ] && [ "$(echo "$version" | cut -d. -f2)" -ge 8 ] 2>/dev/null; then
        check_pass "Java $version"
    else
        check_fail "Java 版本过低 ($version)，需要 1.8+"
    fi
    check_pass "JAVA_HOME: ${JAVA_HOME:-未设置}"
else
    check_fail "未安装 Java"
fi
echo ""

echo "[2] Kerberos 客户端"
if command -v kinit &> /dev/null; then
    check_pass "kinit 已安装"
else
    check_fail "未安装 Kerberos 客户端"
    echo "     Ubuntu/Debian: sudo apt-get install -y krb5-user"
    echo "     CentOS/RHEL: sudo yum install -y krb5-workstation"
fi
echo ""

echo "[3] TDH-Client"
if [ -d "$TDH_CLIENT" ]; then
    check_pass "TDH-Client: $TDH_CLIENT"
    
    if [ -L "$TDH_CLIENT/conf" ]; then
        target=$(readlink "$TDH_CLIENT/conf")
        check_pass "conf -> $target"
    else
        check_warn "conf 不是软链接"
    fi
    
    if [ -L "$TDH_CLIENT/kerberos" ]; then
        target=$(readlink "$TDH_CLIENT/kerberos")
        check_pass "kerberos -> $target"
    else
        check_warn "kerberos 不是软链接"
    fi
    
    if [ -f "$TDH_CLIENT/init.sh" ]; then
        check_pass "init.sh 存在"
    else
        check_fail "init.sh 不存在"
    fi
else
    check_fail "TDH-Client 不存在: $TDH_CLIENT"
fi
echo ""

echo "[4] 环境变量"
for var in HADOOP_HOME HADOOP_CONF_DIR HIVE_HOME HIVE_CONF_DIR KAFKA_HOME ZOOKEEPER_HOME; do
    val="${!var}"
    if [ -n "$val" ]; then
        check_pass "$var=$val"
    else
        check_warn "$var 未设置 (需要执行 source init.sh n n)"
    fi
done
echo ""

echo "[5] Kerberos 状态"
if command -v klist &> /dev/null; then
    if klist -s 2>/dev/null; then
        principal=$(klist 2>/dev/null | grep "Default principal" | awk '{print $3}')
        check_pass "有效票据: $principal"
    else
        check_warn "无有效 Kerberos 票据"
    fi
else
    check_warn "klist 不可用"
fi
echo ""

echo "[6] 集群配置"
if [ -d "$TDH_CLIENT/conf" ]; then
    for conf_dir in "$TDH_CLIENT/conf"/tdfs* "$TDH_CLIENT/conf"/hdfs*; do
        [ -d "$conf_dir" ] || continue
        auth=$(grep -A1 "hadoop.security.authentication" "$conf_dir/core-site.xml" 2>/dev/null | grep -oP '<value>\K[^<]+')
        if [ -n "$auth" ]; then
            check_pass "HDFS 认证方式: $auth"
        fi
    done
fi
echo ""

echo "=========================================="
echo "  检查完成: $pass 通过, $fail 失败, $warn 警告"
echo "=========================================="

if [ $fail -gt 0 ]; then
    echo ""
    echo "请先解决失败项后再使用 TDH 客户端"
    return 1 2>/dev/null || exit 1
fi
