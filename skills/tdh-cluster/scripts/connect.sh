#!/bin/bash
# TDH 集群连接脚本
# 用法: source connect.sh [service]
# 服务选项: hdfs, yarn, hive, kafka, zookeeper, all (默认)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 集群配置
CLUSTER_NAME="Transwarp"
KERBEROS_REALM="TDHXH"
MANAGER_URL="https://172.18.135.39:8180"

# 节点地址
NODE1="xh13537"
NODE2="xh13538"
NODE3="xh13539"
NODE1_IP="172.18.135.37"
NODE2_IP="172.18.135.38"
NODE3_IP="172.18.135.39"

# 服务端口
HDFS_PORT=8020
YARN_PORT=8032
HIVE_PORT=10000
ZK_PORT=2181
KAFKA_PORT=9092
KDC_PORT=1088

# TDH-Client 路径检测
find_tdh_client() {
    # 尝试多个可能的位置
    local paths=(
        "$HOME/tdh-client/TDH-Client"
        "$HOME/TDH-Client"
        "/opt/TDH-Client"
        "./TDH-Client"
    )
    
    for path in "${paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# 打印信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Kerberos 客户端
check_kerberos() {
    if ! command -v kinit &> /dev/null; then
        print_error "Kerberos 客户端未安装"
        echo "请安装 Kerberos 客户端:"
        echo "  Ubuntu/Debian: sudo apt-get install -y krb5-user"
        echo "  CentOS/RHEL: sudo yum install -y krb5-workstation"
        echo "  macOS: brew install krb5"
        return 1
    fi
    print_success "Kerberos 客户端已安装"
    return 0
}

# 初始化 TDH 环境
init_tdh_env() {
    local tdh_client=$(find_tdh_client)
    
    if [ -z "$tdh_client" ]; then
        print_error "找不到 TDH-Client 目录"
        echo "请确保 TDH-Client 已解压到以下位置之一:"
        echo "  ~/tdh-client/TDH-Client"
        echo "  ~/TDH-Client"
        echo "  /opt/TDH-Client"
        return 1
    fi
    
    print_info "找到 TDH-Client: $tdh_client"
    
    # 检查 init.sh
    if [ ! -f "$tdh_client/init.sh" ]; then
        print_error "找不到 init.sh 脚本"
        return 1
    fi
    
    # 设置 Kerberos 配置
    if [ -f "$tdh_client/kerberos/krb5.conf" ]; then
        export KRB5_CONFIG="$tdh_client/kerberos/krb5.conf"
        print_info "设置 KRB5_CONFIG=$KRB5_CONFIG"
    fi
    
    # 运行 init.sh (静默模式，使用绝对路径不改变工作目录)
    print_info "初始化 TDH 环境..."
    source "$tdh_client/init.sh" n n > /dev/null 2>&1
    
    # 验证环境变量
    if [ -z "$HADOOP_HOME" ]; then
        print_warning "HADOOP_HOME 未设置，手动设置"
        export HADOOP_HOME="$tdh_client/hadoop/hadoop"
        export PATH="$HADOOP_HOME/bin:$PATH"
    fi
    
    print_success "TDH 环境初始化完成"
    
    # 显示环境信息
    echo ""
    echo "=========================================="
    echo "  TDH 集群连接信息"
    echo "=========================================="
    echo "  集群名称: $CLUSTER_NAME"
    echo "  Kerberos Realm: $KERBEROS_REALM"
    echo "  Manager: $MANAGER_URL"
    echo "  HDFS: hdfs://nameservice1"
    echo "  YARN: $NODE2:$YARN_PORT, $NODE3:$YARN_PORT"
    echo "  HiveServer2: $NODE1:$HIVE_PORT"
    echo "  ZooKeeper: $NODE1:$ZK_PORT, $NODE2:$ZK_PORT, $NODE3:$ZK_PORT"
    echo "  Kafka: $NODE1:$KAFKA_PORT"
    echo "=========================================="
    echo ""
    
    return 0
}

# Kerberos 认证
kerberos_auth() {
    local username="$1"
    
    if [ -z "$username" ]; then
        read -p "请输入 Kerberos 用户名: " username
    fi
    
    if [ -z "$username" ]; then
        print_error "用户名不能为空"
        return 1
    fi
    
    print_info "正在获取 Kerberos 票据..."
    
    # 检查是否已有有效票据
    if klist -s 2>/dev/null; then
        local current_principal=$(klist 2>/dev/null | grep "Default principal" | awk '{print $3}')
        print_warning "已有有效票据: $current_principal"
        read -p "是否重新认证? (y/N): " reauth
        if [[ ! "$reauth" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    kinit "$username@$KERBEROS_REALM"
    
    if [ $? -eq 0 ]; then
        print_success "Kerberos 认证成功"
        klist
    else
        print_error "Kerberos 认证失败"
        return 1
    fi
}

# 使用 keytab 认证
kerberos_auth_keytab() {
    local keytab_file="$1"
    local principal="$2"
    
    if [ -z "$keytab_file" ] || [ -z "$principal" ]; then
        print_error "用法: kerberos_auth_keytab <keytab_file> <principal>"
        return 1
    fi
    
    if [ ! -f "$keytab_file" ]; then
        print_error "Keytab 文件不存在: $keytab_file"
        return 1
    fi
    
    print_info "使用 keytab 认证..."
    kinit -kt "$keytab_file" "$principal"
    
    if [ $? -eq 0 ]; then
        print_success "Kerberos keytab 认证成功"
        klist
    else
        print_error "Kerberos keytab 认证失败"
        return 1
    fi
}

# HDFS 连接
connect_hdfs() {
    print_info "测试 HDFS 连接..."
    hdfs dfs -ls / > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "HDFS 连接成功"
        echo ""
        echo "HDFS 根目录内容:"
        hdfs dfs -ls /
        echo ""
        echo "常用命令:"
        echo "  hdfs dfs -ls /path       # 查看文件"
        echo "  hdfs dfs -put local /hdfs # 上传文件"
        echo "  hdfs dfs -get /hdfs local # 下载文件"
        echo "  hdfs dfs -mkdir /path     # 创建目录"
    else
        print_error "HDFS 连接失败"
        echo "请检查:"
        echo "  1. Kerberos 票据是否有效 (klist)"
        echo "  2. HADOOP_CONF_DIR 是否正确 ($HADOOP_CONF_DIR)"
        return 1
    fi
}

# YARN 连接
connect_yarn() {
    print_info "测试 YARN 连接..."
    yarn application -list > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "YARN 连接成功"
        echo ""
        echo "YARN 应用列表:"
        yarn application -list 2>/dev/null | head -10
        echo ""
        echo "常用命令:"
        echo "  yarn application -list              # 查看应用"
        echo "  yarn application -kill <app_id>     # 杀死应用"
        echo "  yarn node -list                     # 查看节点"
        echo "  yarn top                            # 查看资源"
    else
        print_error "YARN 连接失败"
        return 1
    fi
}

# Hive/Inceptor 连接
connect_hive() {
    print_info "测试 HiveServer2 连接..."
    
    # 检查 beeline 是否可用
    if ! command -v beeline &> /dev/null; then
        print_error "beeline 命令不可用"
        return 1
    fi
    
    print_success "beeline 命令可用"
    echo ""
    echo "连接命令:"
    echo "  beeline -u \"jdbc:hive2://$NODE1:$HIVE_PORT/default;principal=hive/_HOST@$KERBEROS_REALM\""
    echo ""
    echo "执行 SQL:"
    echo "  beeline -u \"jdbc:hive2://$NODE1:$HIVE_PORT/default;principal=hive/_HOST@$KERBEROS_REALM\" -e \"SHOW DATABASES;\""
}

# Kafka 连接
connect_kafka() {
    print_info "测试 Kafka 连接..."
    
    # 检查 kafka-topics.sh 是否可用
    if [ ! -f "$KAFKA_HOME/bin/kafka-topics.sh" ]; then
        print_error "kafka-topics.sh 不可用"
        return 1
    fi
    
    print_success "Kafka 命令可用"
    echo ""
    echo "常用命令:"
    echo "  kafka-topics.sh --list --bootstrap-server $NODE1:$KAFKA_PORT"
    echo "  kafka-topics.sh --create --topic my-topic --bootstrap-server $NODE1:$KAFKA_PORT --partitions 3 --replication-factor 2"
    echo "  kafka-console-producer.sh --topic my-topic --bootstrap-server $NODE1:$KAFKA_PORT"
    echo "  kafka-console-consumer.sh --topic my-topic --bootstrap-server $NODE1:$KAFKA_PORT --from-beginning"
}

# ZooKeeper 连接
connect_zookeeper() {
    print_info "测试 ZooKeeper 连接..."
    
    # 检查 zookeeper-client 是否可用
    if ! command -v zookeeper-client &> /dev/null; then
        print_error "zookeeper-client 命令不可用"
        return 1
    fi
    
    print_success "ZooKeeper 客户端可用"
    echo ""
    echo "连接命令:"
    echo "  zookeeper-client -server $NODE1:$ZK_PORT"
}

# 显示帮助
show_help() {
    echo "TDH 集群连接脚本"
    echo ""
    echo "用法:"
    echo "  source connect.sh [command] [options]"
    echo ""
    echo "命令:"
    echo "  init                    初始化 TDH 环境"
    echo "  auth [username]         Kerberos 认证 (交互式)"
    echo "  keytab <file> <principal>  使用 keytab 认证"
    echo "  hdfs                    测试 HDFS 连接"
    echo "  yarn                    测试 YARN 连接"
    echo "  hive                    测试 Hive 连接"
    echo "  kafka                   测试 Kafka 连接"
    echo "  zookeeper               测试 ZooKeeper 连接"
    echo "  all                     测试所有服务 (默认)"
    echo "  help                    显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  source connect.sh init          # 初始化环境"
    echo "  source connect.sh auth admin    # 使用 admin 用户认证"
    echo "  source connect.sh hdfs          # 测试 HDFS"
}

# 主函数
main() {
    local command="${1:-all}"
    
    case "$command" in
        init)
            check_kerberos && init_tdh_env
            ;;
        auth)
            shift
            kerberos_auth "$@"
            ;;
        keytab)
            shift
            kerberos_auth_keytab "$@"
            ;;
        hdfs)
            init_tdh_env > /dev/null 2>&1 && connect_hdfs
            ;;
        yarn)
            init_tdh_env > /dev/null 2>&1 && connect_yarn
            ;;
        hive)
            init_tdh_env > /dev/null 2>&1 && connect_hive
            ;;
        kafka)
            init_tdh_env > /dev/null 2>&1 && connect_kafka
            ;;
        zookeeper)
            init_tdh_env > /dev/null 2>&1 && connect_zookeeper
            ;;
        all)
            check_kerberos && init_tdh_env
            echo ""
            echo "测试服务连接..."
            echo ""
            connect_hdfs
            echo ""
            connect_yarn
            echo ""
            connect_hive
            echo ""
            connect_kafka
            echo ""
            connect_zookeeper
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            show_help
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"
