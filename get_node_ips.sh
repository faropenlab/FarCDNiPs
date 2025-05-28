#!/bin/bash

# 节点IP获取脚本
# 使用方法: ./get_node_ips.sh [type] [nodeClusterId] [isInstalled] [选项]
# type: ipv4, ipv6, all (默认: all)
# nodeClusterId: 节点集群ID (默认: 1)
# isInstalled: 是否已安装 true/false (默认: true)

# 设置API基础URL
API_BASE_URL="https://open.farcdn.net/api/source"
API_ENDPOINT="/getNodeIPs"

# 全局变量
JQ_AVAILABLE=false
RESPONSE=""
VERBOSE=false
FORCE_HTTP1=false

# 默认参数
TYPE="all"
NODE_CLUSTER_ID="1"
IS_INSTALLED="true"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的输出
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示使用帮助
show_help() {
    echo "节点IP获取脚本使用说明:"
    echo ""
    echo "用法: $0 [选项] [type] [nodeClusterId] [isInstalled]"
    echo ""
    echo "参数:"
    echo "  type         IP类型 (ipv4|ipv6|all) - 默认: all"
    echo "  nodeClusterId 节点集群ID - 默认: 1"
    echo "  isInstalled  是否已安装 (true|false) - 默认: true"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -v, --verbose        详细输出模式"
    echo "  -f, --force-http1    强制使用HTTP/1.1"
    echo "  --test               运行诊断测试"
    echo ""
    echo "示例:"
    echo "  $0                        # 获取所有IP"
    echo "  $0 ipv4                   # 只获取IPv4地址"
    echo "  $0 ipv6                   # 只获取IPv6地址"
    echo "  $0 all 2                  # 获取集群2的所有IP"
    echo "  $0 ipv4 1 false           # 获取集群1未安装节点的IPv4地址"
    echo "  $0 -v ipv6                # 详细模式获取IPv6地址"
    echo "  $0 -f -v all              # 强制HTTP/1.1 + 详细模式获取所有IP"
    echo "  $0 --test                 # 运行系统诊断测试"
    echo ""
    echo "故障排除:"
    echo "  如果在Debian系统上遇到空响应问题，请尝试："
    echo "  1) $0 --test              # 运行完整诊断"
    echo "  2) $0 -v -f ipv4          # 详细模式 + 强制HTTP/1.1"
    echo "  3) 手动测试API连接："
    echo "     curl -v -X POST -H 'Content-Type: application/json' \\"
    echo "          -d '{\"type\":\"ipv4\",\"nodeClusterId\":1,\"isInstalled\":true}' \\"
    echo "          https://open.farcdn.net/api/source/getNodeIPs"
    echo ""
}

# 解析命令行参数
parse_arguments() {
    local positional_args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force-http1)
                FORCE_HTTP1=true
                shift
                ;;
            --test)
                run_diagnostic_test
                exit 0
                ;;
            -*)
                print_colored $RED "错误: 未知选项 $1"
                show_help
                exit 1
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done
    
    # 设置位置参数
    if [[ ${#positional_args[@]} -gt 0 ]]; then
        TYPE="${positional_args[0]}"
    fi
    if [[ ${#positional_args[@]} -gt 1 ]]; then
        NODE_CLUSTER_ID="${positional_args[1]}"
    fi
    if [[ ${#positional_args[@]} -gt 2 ]]; then
        IS_INSTALLED="${positional_args[2]}"
    fi
}

# 检查参数有效性
validate_params() {
    if [[ "$TYPE" != "ipv4" && "$TYPE" != "ipv6" && "$TYPE" != "all" ]]; then
        print_colored $RED "错误: type参数无效，必须是 ipv4, ipv6 或 all"
        show_help
        exit 1
    fi
    
    if ! [[ "$NODE_CLUSTER_ID" =~ ^[0-9]+$ ]]; then
        print_colored $RED "错误: nodeClusterId必须是数字"
        show_help
        exit 1
    fi
    
    if [[ "$IS_INSTALLED" != "true" && "$IS_INSTALLED" != "false" ]]; then
        print_colored $RED "错误: isInstalled必须是 true 或 false"
        show_help
        exit 1
    fi
}

# 检查必要工具
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_colored $RED "错误: 需要安装 curl 工具"
        exit 1
    fi
    
    # 检查curl版本和支持的功能
    if [ "$VERBOSE" = true ]; then
        print_colored $BLUE "curl版本信息:"
        curl --version
        echo ""
    fi
    
    # 检查curl的SSL支持
    local curl_version_info=$(curl --version 2>/dev/null | head -n 1)
    if echo "$curl_version_info" | grep -q "OpenSSL\|GnuTLS\|NSS\|Secure Transport"; then
        if [ "$VERBOSE" = true ]; then
            print_colored $GREEN "✅ curl支持SSL/TLS"
        fi
    else
        print_colored $YELLOW "⚠️  警告: curl可能不支持SSL/TLS，这可能导致HTTPS请求失败"
    fi
    
    # 检查curl的HTTP/2支持
    if curl --version 2>/dev/null | grep -q "HTTP2"; then
        if [ "$VERBOSE" = true ]; then
            print_colored $GREEN "✅ curl支持HTTP/2"
        fi
    else
        if [ "$VERBOSE" = true ]; then
            print_colored $YELLOW "⚠️  curl不支持HTTP/2，将使用HTTP/1.1"
        fi
        # 如果不支持HTTP/2，自动启用强制HTTP/1.1
        FORCE_HTTP1=true
    fi
    
    if ! command -v jq &> /dev/null; then
        print_colored $YELLOW "警告: 建议安装 jq 工具以获得更好的JSON格式化输出"
        JQ_AVAILABLE=false
    else
        JQ_AVAILABLE=true
        if [ "$VERBOSE" = true ]; then
            print_colored $GREEN "✅ jq工具可用"
        fi
    fi
    
    # 在Debian系统上进行额外检查
    if [ -f /etc/debian_version ]; then
        if [ "$VERBOSE" = true ]; then
            print_colored $BLUE "检测到Debian系统，进行额外检查..."
            
            # 检查CA证书
            if [ -d /etc/ssl/certs ] && [ "$(ls -1 /etc/ssl/certs/ | wc -l)" -gt 0 ]; then
                print_colored $GREEN "✅ CA证书目录存在"
            else
                print_colored $YELLOW "⚠️  CA证书可能缺失，建议运行: sudo apt install ca-certificates"
            fi
            
            # 检查时间同步
            if command -v timedatectl &> /dev/null; then
                local time_sync=$(timedatectl status 2>/dev/null | grep "System clock synchronized" | grep -o "yes\|no" || echo "unknown")
                if [ "$time_sync" = "yes" ]; then
                    print_colored $GREEN "✅ 系统时间同步正常"
                else
                    print_colored $YELLOW "⚠️  系统时间可能未同步，这可能导致SSL证书验证失败"
                fi
            fi
        fi
    fi
}

# 调用API获取IP
get_node_ips() {
    local full_url="${API_BASE_URL}${API_ENDPOINT}"
    
    if [ "$VERBOSE" = true ]; then
        print_colored $BLUE "正在获取节点IP地址..."
        print_colored $BLUE "API URL: $full_url"
        print_colored $BLUE "参数: type=$TYPE, nodeClusterId=$NODE_CLUSTER_ID, isInstalled=$IS_INSTALLED"
        if [ "$FORCE_HTTP1" = true ]; then
            print_colored $YELLOW "使用HTTP/1.1协议"
        fi
        echo ""
    fi
    
    # 构建JSON请求体
    local json_data="{\"type\":\"$TYPE\",\"nodeClusterId\":$NODE_CLUSTER_ID,\"isInstalled\":$IS_INSTALLED}"
    
    if [ "$VERBOSE" = true ]; then
        print_colored $BLUE "请求体: $json_data"
        echo ""
    fi
    
    # 构建curl命令
    local curl_cmd=(
        curl -s -X POST
        -H "Content-Type: application/json"
        -H "Accept: application/json"
        -H "User-Agent: NodeIP-Script/1.0"
        --connect-timeout 30
        --max-time 60
        -d "$json_data"
    )
    
    # 如果强制使用HTTP/1.1
    if [ "$FORCE_HTTP1" = true ]; then
        curl_cmd+=(--http1.1)
    fi
    
    # 添加详细输出（如果需要）
    if [ "$VERBOSE" = true ]; then
        curl_cmd+=(-v)
        print_colored $BLUE "执行curl命令:"
        printf '%s ' "${curl_cmd[@]}"
        echo " $full_url"
        echo ""
    fi
    
    curl_cmd+=("$full_url")
    
    # 发送POST请求
    if [ "$VERBOSE" = true ]; then
        # 详细模式时显示stderr输出
        local temp_file=$(mktemp)
        local response=$("${curl_cmd[@]}" 2>"$temp_file")
        local curl_exit_code=$?
        
        # 显示curl详细输出
        local curl_verbose_output=$(cat "$temp_file")
        if [[ -n "$curl_verbose_output" ]]; then
            print_colored $BLUE "curl详细输出:"
            echo "$curl_verbose_output"
            echo ""
        fi
        
        # 清理临时文件
        rm -f "$temp_file"
    else
        # 静默模式
        local response=$("${curl_cmd[@]}" 2>/dev/null)
        local curl_exit_code=$?
    fi
    
    # 检查curl是否成功执行
    if [ $curl_exit_code -ne 0 ]; then
        print_colored $RED "错误: API请求失败 (curl退出码: $curl_exit_code)"
        
        # 根据退出码给出更具体的错误信息
        case $curl_exit_code in
            6)
                print_colored $RED "无法解析主机名"
                print_colored $YELLOW "建议: 1) 检查DNS设置  2) 尝试: nslookup open.farcdn.net"
                ;;
            7)
                print_colored $RED "无法连接到服务器"
                print_colored $YELLOW "建议: 1) 检查网络连接  2) 检查防火墙设置  3) 尝试: ping open.farcdn.net"
                ;;
            28)
                print_colored $RED "请求超时"
                print_colored $YELLOW "建议: 1) 检查网络速度  2) 稍后重试"
                ;;
            35)
                print_colored $RED "SSL连接错误"
                print_colored $YELLOW "建议: 1) 检查系统时间  2) 更新CA证书  3) 尝试: curl -k (不验证SSL)"
                ;;
            92)
                print_colored $RED "HTTP/2协议错误，尝试使用 -f 选项强制HTTP/1.1"
                ;;
            *)
                print_colored $RED "未知错误，请检查网络连接"
                ;;
        esac
        
        # 在Debian系统上提供额外的调试建议
        if [ -f /etc/debian_version ]; then
            print_colored $YELLOW "Debian系统调试建议:"
            print_colored $YELLOW "1) 检查curl版本: curl --version"
            print_colored $YELLOW "2) 测试基本连接: curl -I https://open.farcdn.net"
            print_colored $YELLOW "3) 使用详细模式重试: ./get_node_ips.sh -v -f $TYPE"
        fi
        
        exit 1
    fi
    
    # 检查响应是否为空
    if [ -z "$response" ]; then
        print_colored $RED "错误: 收到空响应"
        
        print_colored $YELLOW "可能的原因:"
        print_colored $YELLOW "1) 服务器没有返回任何数据"
        print_colored $YELLOW "2) 请求被服务器阻止或拒绝"
        print_colored $YELLOW "3) 网络连接中断"
        print_colored $YELLOW "4) HTTP/2协议兼容性问题"
        print_colored $YELLOW "5) SSL/TLS握手失败"
        
        print_colored $YELLOW "调试建议:"
        print_colored $YELLOW "1) 使用详细模式: ./get_node_ips.sh -v $TYPE"
        print_colored $YELLOW "2) 强制HTTP/1.1: ./get_node_ips.sh -f $TYPE"
        print_colored $YELLOW "3) 组合使用: ./get_node_ips.sh -v -f $TYPE"
        print_colored $YELLOW "4) 手动测试: curl -v -X POST -H \"Content-Type: application/json\" -d '$json_data' $full_url"
        
        # 如果是Debian系统，提供系统特定的建议
        if [ -f /etc/debian_version ]; then
            echo ""
            print_colored $BLUE "Debian系统特定检查:"
            print_colored $YELLOW "1) 更新包列表: sudo apt update"
            print_colored $YELLOW "2) 更新curl: sudo apt install --upgrade curl"
            print_colored $YELLOW "3) 安装CA证书: sudo apt install ca-certificates"
            print_colored $YELLOW "4) 检查openssl: openssl version"
        fi
        
        exit 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        print_colored $BLUE "收到响应 (长度: ${#response} 字符):"
        echo "$response"
        echo ""
    fi
    
    # 解析响应
    parse_response "$response"
}

# 解析API响应
parse_response() {
    local response="$1"
    # 将response设为全局变量，以便save_to_file函数可以访问
    RESPONSE="$response"
    
    # 检查响应是否是有效的JSON
    if [ "$JQ_AVAILABLE" = true ]; then
        if ! echo "$response" | jq empty 2>/dev/null; then
            print_colored $RED "❌ 响应不是有效的JSON格式"
            echo "响应内容: $response"
            exit 1
        fi
    fi
    
    # 检查响应是否包含成功标识
    local is_success=false
    if [ "$JQ_AVAILABLE" = true ]; then
        # 使用jq检查多种可能的成功标识
        if echo "$response" | jq -e '.code == 200 or .status == "success" or .success == true or (.data // empty)' >/dev/null 2>&1; then
            is_success=true
        fi
    else
        # 没有jq时的简单检查
        if echo "$response" | grep -q -E '"code":200|"status":"success"|"success":true|"data":[{[]'; then
            is_success=true
        fi
    fi
    
    if [ "$is_success" = true ]; then
        print_colored $GREEN "✅ 成功获取IP地址"
        echo ""
        
        if [ "$JQ_AVAILABLE" = true ]; then
            # 首先显示完整的JSON响应
            echo "完整响应:"
            echo "$response" | jq '.'
            
            # 提取并显示IP列表
            echo ""
            print_colored $YELLOW "========== IP地址列表 =========="
            
            local has_data=false
            case $TYPE in
                "ipv4")
                    if echo "$response" | jq -e '.data.ips' >/dev/null 2>&1; then
                        echo "$response" | jq -r '.data.ips[]' 2>/dev/null
                        has_data=true
                    elif echo "$response" | jq -e '.data.ipv4_list' >/dev/null 2>&1; then
                        echo "$response" | jq -r '.data.ipv4_list[]' 2>/dev/null
                        has_data=true
                    fi
                    ;;
                "ipv6")
                    if echo "$response" | jq -e '.data.ips' >/dev/null 2>&1; then
                        echo "$response" | jq -r '.data.ips[]' 2>/dev/null
                        has_data=true
                    elif echo "$response" | jq -e '.data.ipv6_list' >/dev/null 2>&1; then
                        echo "$response" | jq -r '.data.ipv6_list[]' 2>/dev/null
                        has_data=true
                    fi
                    ;;
                "all")
                    if echo "$response" | jq -e '.data.ipv4_list' >/dev/null 2>&1; then
                        print_colored $BLUE "IPv4地址:"
                        echo "$response" | jq -r '.data.ipv4_list[]' 2>/dev/null
                        has_data=true
                    fi
                    if echo "$response" | jq -e '.data.ipv6_list' >/dev/null 2>&1; then
                        echo ""
                        print_colored $BLUE "IPv6地址:"
                        echo "$response" | jq -r '.data.ipv6_list[]' 2>/dev/null
                        has_data=true
                    fi
                    if echo "$response" | jq -e '.data.ips' >/dev/null 2>&1; then
                        print_colored $BLUE "所有IP地址:"
                        echo "$response" | jq -r '.data.ips[]' 2>/dev/null
                        has_data=true
                    fi
                    ;;
            esac
            
            if [ "$has_data" = false ]; then
                print_colored $YELLOW "未找到IP数据，可能数据结构不同"
            fi
            
            # 显示统计信息
            echo ""
            print_colored $YELLOW "========== 统计信息 =========="
            
            # 获取基础统计数据
            local total_count=$(echo "$response" | jq -r '.data.total_count // .data.count // 0' 2>/dev/null)
            local api_ipv4_count=$(echo "$response" | jq -r '.data.ipv4_count // 0' 2>/dev/null)
            local api_ipv6_count=$(echo "$response" | jq -r '.data.ipv6_count // 0' 2>/dev/null)
            
            # 计算实际IP数量（从数组长度）
            local actual_ipv4_count=0
            local actual_ipv6_count=0
            local actual_total_count=0
            
            if echo "$response" | jq -e '.data.ipv4_list' >/dev/null 2>&1; then
                actual_ipv4_count=$(echo "$response" | jq -r '.data.ipv4_list | length' 2>/dev/null)
            fi
            
            if echo "$response" | jq -e '.data.ipv6_list' >/dev/null 2>&1; then
                actual_ipv6_count=$(echo "$response" | jq -r '.data.ipv6_list | length' 2>/dev/null)
            fi
            
            if echo "$response" | jq -e '.data.ips' >/dev/null 2>&1; then
                actual_total_count=$(echo "$response" | jq -r '.data.ips | length' 2>/dev/null)
            fi
            
            echo "集群ID: $NODE_CLUSTER_ID"
            echo "类型: $TYPE"
            echo "已安装状态: $IS_INSTALLED"
            
            case $TYPE in
                "ipv4")
                    local display_count=$actual_ipv4_count
                    if [ "$display_count" = "0" ] && [ "$actual_total_count" != "0" ]; then
                        display_count=$actual_total_count
                    fi
                    if [ "$display_count" = "0" ] && [ "$api_ipv4_count" != "0" ]; then
                        display_count=$api_ipv4_count
                    fi
                    if [ "$display_count" = "0" ] && [ "$total_count" != "0" ]; then
                        display_count=$total_count
                    fi
                    echo "IPv4地址数量: $display_count"
                    ;;
                "ipv6")
                    local display_count=$actual_ipv6_count
                    if [ "$display_count" = "0" ] && [ "$actual_total_count" != "0" ]; then
                        display_count=$actual_total_count
                    fi
                    if [ "$display_count" = "0" ] && [ "$api_ipv6_count" != "0" ]; then
                        display_count=$api_ipv6_count
                    fi
                    if [ "$display_count" = "0" ] && [ "$total_count" != "0" ]; then
                        display_count=$total_count
                    fi
                    echo "IPv6地址数量: $display_count"
                    ;;
                "all")
                    local display_total=$actual_total_count
                    if [ "$display_total" = "0" ] && [ "$total_count" != "0" ]; then
                        display_total=$total_count
                    fi
                    if [ "$display_total" = "0" ]; then
                        display_total=$((actual_ipv4_count + actual_ipv6_count))
                    fi
                    
                    if [ "$display_total" != "0" ]; then
                        echo "总IP数量: $display_total"
                    fi
                    if [ "$actual_ipv4_count" != "0" ] || [ "$api_ipv4_count" != "0" ]; then
                        local ipv4_show=$actual_ipv4_count
                        if [ "$ipv4_show" = "0" ]; then
                            ipv4_show=$api_ipv4_count
                        fi
                        echo "IPv4数量: $ipv4_show"
                    fi
                    if [ "$actual_ipv6_count" != "0" ] || [ "$api_ipv6_count" != "0" ]; then
                        local ipv6_show=$actual_ipv6_count
                        if [ "$ipv6_show" = "0" ]; then
                            ipv6_show=$api_ipv6_count
                        fi
                        echo "IPv6数量: $ipv6_show"
                    fi
                    ;;
            esac
            
        else
            # 没有jq时的简单输出
            print_colored $YELLOW "原始响应 (建议安装jq获得更好的格式化):"
            echo "$response"
        fi
        
    else
        print_colored $RED "❌ API返回错误或非预期响应"
        echo ""
        if [ "$JQ_AVAILABLE" = true ]; then
            # 尝试提取错误信息
            local error_msg=$(echo "$response" | jq -r '.message // .error // .msg // "未知错误"' 2>/dev/null)
            local error_code=$(echo "$response" | jq -r '.code // .status_code // "unknown"' 2>/dev/null)
            
            print_colored $RED "错误代码: $error_code"
            print_colored $RED "错误信息: $error_msg"
            echo ""
            echo "完整响应:"
            echo "$response" | jq '.'
        else
            echo "$response"
        fi
        exit 1
    fi
}

# 保存IP到文件
save_to_file() {
    if [ "$JQ_AVAILABLE" = true ] && [ -n "$RESPONSE" ]; then
        local filename="node_ips_${TYPE}_cluster${NODE_CLUSTER_ID}_$(date +%Y%m%d_%H%M%S).txt"
        echo ""
        print_colored $YELLOW "是否保存IP列表到文件? (y/n): "
        read -r save_choice
        
        if [[ "$save_choice" == "y" || "$save_choice" == "Y" ]]; then
            local saved=false
            case $TYPE in
                "ipv4")
                    if echo "$RESPONSE" | jq -e '.data.ips' >/dev/null 2>&1; then
                        echo "$RESPONSE" | jq -r '.data.ips[]' > "$filename"
                        saved=true
                    elif echo "$RESPONSE" | jq -e '.data.ipv4_list' >/dev/null 2>&1; then
                        echo "$RESPONSE" | jq -r '.data.ipv4_list[]' > "$filename"
                        saved=true
                    fi
                    ;;
                "ipv6")
                    if echo "$RESPONSE" | jq -e '.data.ips' >/dev/null 2>&1; then
                        echo "$RESPONSE" | jq -r '.data.ips[]' > "$filename"
                        saved=true
                    elif echo "$RESPONSE" | jq -e '.data.ipv6_list' >/dev/null 2>&1; then
                        echo "$RESPONSE" | jq -r '.data.ipv6_list[]' > "$filename"
                        saved=true
                    fi
                    ;;
                "all")
                    {
                        echo "# 节点IP列表"
                        echo "# 集群ID: $NODE_CLUSTER_ID"
                        echo "# 生成时间: $(date)"
                        echo ""
                        if echo "$RESPONSE" | jq -e '.data.ipv4_list' >/dev/null 2>&1; then
                            echo "# IPv4地址"
                            echo "$RESPONSE" | jq -r '.data.ipv4_list[]'
                            echo ""
                        fi
                        if echo "$RESPONSE" | jq -e '.data.ipv6_list' >/dev/null 2>&1; then
                            echo "# IPv6地址"
                            echo "$RESPONSE" | jq -r '.data.ipv6_list[]'
                        fi
                        if echo "$RESPONSE" | jq -e '.data.ips' >/dev/null 2>&1; then
                            echo "# 所有IP地址"
                            echo "$RESPONSE" | jq -r '.data.ips[]'
                        fi
                    } > "$filename"
                    saved=true
                    ;;
            esac
            
            if [ "$saved" = true ]; then
                print_colored $GREEN "✅ IP列表已保存到: $filename"
            else
                print_colored $RED "❌ 保存失败：未找到可保存的IP数据"
            fi
        fi
    fi
}

# 诊断测试函数
run_diagnostic_test() {
    print_colored $GREEN "===================="
    print_colored $GREEN "  系统诊断测试"
    print_colored $GREEN "===================="
    echo ""
    
    # 显示系统信息
    print_colored $BLUE "系统信息:"
    echo "操作系统: $(uname -s)"
    echo "内核版本: $(uname -r)"
    echo "架构: $(uname -m)"
    if [ -f /etc/os-release ]; then
        echo "发行版: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    fi
    echo ""
    
    # 检查curl
    print_colored $BLUE "curl检查:"
    if command -v curl &> /dev/null; then
        print_colored $GREEN "✅ curl已安装"
        echo "版本: $(curl --version | head -n 1)"
        echo "支持的协议: $(curl --version | grep "Protocols:" | cut -d: -f2)"
        echo "支持的特性: $(curl --version | grep "Features:" | cut -d: -f2)"
    else
        print_colored $RED "❌ curl未安装"
    fi
    echo ""
    
    # 检查jq
    print_colored $BLUE "jq检查:"
    if command -v jq &> /dev/null; then
        print_colored $GREEN "✅ jq已安装"
        echo "版本: $(jq --version)"
    else
        print_colored $YELLOW "⚠️  jq未安装 (建议安装)"
    fi
    echo ""
    
    # 检查网络工具
    print_colored $BLUE "网络工具检查:"
    for tool in ping nslookup dig nc telnet; do
        if command -v $tool &> /dev/null; then
            print_colored $GREEN "✅ $tool可用"
        else
            print_colored $YELLOW "⚠️  $tool不可用"
        fi
    done
    echo ""
    
    # DNS测试
    print_colored $BLUE "DNS解析测试:"
    if command -v nslookup &> /dev/null; then
        echo "测试域名: open.farcdn.net"
        nslookup open.farcdn.net || print_colored $RED "DNS解析失败"
    else
        print_colored $YELLOW "nslookup不可用，跳过DNS测试"
    fi
    echo ""
    
    # 连接测试
    print_colored $BLUE "连接测试:"
    local test_url="https://open.farcdn.net"
    echo "测试URL: $test_url"
    
    if command -v curl &> /dev/null; then
        print_colored $BLUE "测试1: 基本HEAD请求"
        if curl -s --connect-timeout 10 --max-time 15 -I "$test_url"; then
            print_colored $GREEN "✅ HEAD请求成功"
        else
            print_colored $RED "❌ HEAD请求失败"
        fi
        echo ""
        
        print_colored $BLUE "测试2: 详细连接信息"
        curl -v --connect-timeout 10 --max-time 15 -I "$test_url" 2>&1 | head -20
        echo ""
        
        print_colored $BLUE "测试3: 强制HTTP/1.1"
        if curl -s --http1.1 --connect-timeout 10 --max-time 15 -I "$test_url"; then
            print_colored $GREEN "✅ HTTP/1.1请求成功"
        else
            print_colored $RED "❌ HTTP/1.1请求失败"
        fi
        echo ""
    fi
    
    # API端点测试
    print_colored $BLUE "API端点测试:"
    local api_url="${API_BASE_URL}${API_ENDPOINT}"
    local test_data='{"type":"ipv4","nodeClusterId":1,"isInstalled":true}'
    
    echo "API URL: $api_url"
    echo "测试数据: $test_data"
    echo ""
    
    if command -v curl &> /dev/null; then
        print_colored $BLUE "执行API测试请求..."
        curl -v -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "User-Agent: NodeIP-Script-Test/1.0" \
            --connect-timeout 30 \
            --max-time 60 \
            -d "$test_data" \
            "$api_url" 2>&1 | head -50
    fi
    
    print_colored $GREEN "诊断测试完成！"
}

# 网络连接测试
test_network_connectivity() {
    if [ "$VERBOSE" = true ]; then
        print_colored $BLUE "测试网络连接..."
        
        # 测试DNS解析
        if command -v nslookup &> /dev/null; then
            print_colored $BLUE "DNS解析测试:"
            if nslookup open.farcdn.net >/dev/null 2>&1; then
                print_colored $GREEN "✅ DNS解析成功"
            else
                print_colored $RED "❌ DNS解析失败"
                print_colored $YELLOW "建议: 1) 检查DNS设置  2) 尝试: nslookup open.farcdn.net 8.8.8.8"
            fi
        fi
        
        # 测试基本连接
        print_colored $BLUE "连接测试:"
        if curl -s --connect-timeout 10 --max-time 15 -I https://open.farcdn.net >/dev/null 2>&1; then
            print_colored $GREEN "✅ HTTPS连接成功"
        else
            print_colored $RED "❌ HTTPS连接失败"
            
            # 尝试HTTP连接
            if curl -s --connect-timeout 10 --max-time 15 -I http://open.farcdn.net >/dev/null 2>&1; then
                print_colored $YELLOW "⚠️  HTTP连接成功，但HTTPS失败"
                print_colored $YELLOW "建议: 检查SSL/TLS设置"
            else
                print_colored $RED "❌ HTTP连接也失败"
                print_colored $YELLOW "建议: 检查网络连接和防火墙设置"
            fi
        fi
        echo ""
    fi
}

# 主函数
main() {
    # 显示脚本标题
    print_colored $GREEN "===================="
    print_colored $GREEN "  节点IP获取工具"
    print_colored $GREEN "===================="
    echo ""
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 验证参数
    validate_params
    
    # 检查依赖
    check_dependencies
    
    # 如果是详细模式，显示解析后的参数
    if [ "$VERBOSE" = true ]; then
        print_colored $BLUE "解析后的参数:"
        print_colored $BLUE "  类型: $TYPE"
        print_colored $BLUE "  集群ID: $NODE_CLUSTER_ID"
        print_colored $BLUE "  已安装: $IS_INSTALLED"
        print_colored $BLUE "  详细模式: $VERBOSE"
        print_colored $BLUE "  强制HTTP/1.1: $FORCE_HTTP1"
        echo ""
    fi
    
    # 测试网络连接（详细模式下）
    test_network_connectivity
    
    # 获取IP地址
    get_node_ips
    
    # 询问是否保存到文件
    save_to_file
    
    print_colored $GREEN "完成!"
}

# 执行主函数
main "$@" 