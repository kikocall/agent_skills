#!/bin/bash

TDH_CLIENT="${TDH_CLIENT:-$HOME/TDH-Client}"

if [ ! -d "$TDH_CLIENT" ]; then
    echo "错误: 找不到 TDH-Client: $TDH_CLIENT"
    echo "请设置 TDH_CLIENT 环境变量"
    return 1 2>/dev/null || exit 1
fi

available_clusters=()
for d in "$TDH_CLIENT"/*-conf; do
    [ -d "$d" ] && available_clusters+=("$(basename "${d%-conf}")")
done

if [ ${#available_clusters[@]} -eq 0 ]; then
    echo "错误: 未找到任何集群配置目录 (*-conf)"
    return 1 2>/dev/null || exit 1
fi

show_usage() {
    echo "用法: source switch-cluster.sh [集群名]"
    echo ""
    echo "可用集群:"
    for c in "${available_clusters[@]}"; do
        echo "  - $c"
    done
    echo ""
    echo "当前配置:"
    ls -l "$TDH_CLIENT/conf" "$TDH_CLIENT/kerberos" 2>/dev/null
}

if [ $# -eq 0 ]; then
    show_usage
    return 0 2>/dev/null || exit 0
fi

cluster_name="$1"

if [[ ! " ${available_clusters[@]} " =~ " ${cluster_name} " ]]; then
    echo "错误: 集群 '$cluster_name' 不存在"
    echo "可用集群: ${available_clusters[*]}"
    return 1 2>/dev/null || exit 1
fi

rm -f "$TDH_CLIENT/conf" "$TDH_CLIENT/kerberos"
ln -s "${cluster_name}-conf" "$TDH_CLIENT/conf"
ln -s "${cluster_name}-kerberos" "$TDH_CLIENT/kerberos"

echo "已切换到集群: $cluster_name"
echo ""
echo "配置链接:"
ls -l "$TDH_CLIENT/conf" "$TDH_CLIENT/kerberos"

if [ -f "$TDH_CLIENT/kerberos/krb5.conf" ]; then
    realm=$(grep -m1 "^default_realm" "$TDH_CLIENT/kerberos/krb5.conf" | awk '{print $3}')
    echo ""
    echo "Kerberos Realm: $realm"
fi

echo ""
echo "下一步: source $TDH_CLIENT/init.sh n n"
