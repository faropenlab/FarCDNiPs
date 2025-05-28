# FarCDNiPs
获取集群节点所有iP地址，方便过白

## 🚀 特性

- ✅ **多种IP类型支持**: IPv4、IPv6、全部
- ✅ **智能协议处理**: 自动处理HTTP/2协议问题，支持强制HTTP/1.1
- ✅ **详细输出模式**: 可查看完整的API请求和响应过程
- ✅ **准确统计信息**: 智能计算实际IP数量
- ✅ **文件导出功能**: 支持将IP列表保存到文件
- ✅ **丰富的节点信息**: 包含节点名称、路由信息、地理位置等
- ✅ **错误处理**: 完善的错误检测和友好的错误提示
- ✅ **跨平台兼容**: 支持Linux、macOS等Unix系统

## 📋 系统要求

### 必需工具
- `bash` (版本 4.0+)
- `curl` (支持HTTPS)

### 推荐工具
- `jq` - 用于更好的JSON格式化和解析

### 安装依赖

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install curl jq
```

**CentOS/RHEL:**
```bash
sudo yum install curl jq
# 或使用 dnf (较新版本)
sudo dnf install curl jq
```

**macOS:**
```bash
# 使用 Homebrew
brew install curl jq

# 使用 MacPorts
sudo port install curl jq
```

## 🛠️ 安装

1. **下载脚本**:
   ```bash
   wget https://raw.githubusercontent.com/faropenlab/FarCDNiPs/refs/heads/main/get_node_ips.sh
   # 或
   curl -O https://raw.githubusercontent.com/faropenlab/FarCDNiPs/refs/heads/main/get_node_ips.sh
   ```

2. **添加执行权限**:
   ```bash
   chmod +x get_node_ips.sh
   ```

3. **验证安装** (可选):
   ```bash
   ./get_node_ips.sh --help
   ```

## 📖 使用方法

### 基本语法
```bash
./get_node_ips.sh [选项] [type] [nodeClusterId] [isInstalled]
```

### 参数说明

#### 位置参数
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `type` | string | `all` | IP类型：`ipv4`、`ipv6`、`all` |
| `nodeClusterId` | number | `1` | 节点集群ID |
| `isInstalled` | boolean | `true` | 是否只获取已安装节点的IP |

#### 选项参数
| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `-v, --verbose` | 详细输出模式 |
| `-f, --force-http1` | 强制使用HTTP/1.1协议 |

## 💡 使用示例

### 基本使用
```bash
# 获取所有IP地址（推荐）
./get_node_ips.sh -f all

# 只获取IPv4地址
./get_node_ips.sh -f ipv4

# 只获取IPv6地址
./get_node_ips.sh -f ipv6
```

### 高级用法
```bash
# 详细模式获取IPv6地址
./get_node_ips.sh -v ipv6

# 强制HTTP/1.1协议获取所有IP
./get_node_ips.sh -f all

# 详细模式 + HTTP/1.1
./get_node_ips.sh -v -f all
```

### 故障排除
```bash
# 如果遇到HTTP/2协议错误
./get_node_ips.sh -f -v all

# 查看详细的请求过程
./get_node_ips.sh -v ipv4
```

## ❌ 错误处理

### 常见错误及解决方法

| 错误码 | 错误描述 | 解决方法 |
|--------|----------|----------|
| 6 | 无法解析主机名 | 检查网络连接和DNS设置 |
| 7 | 无法连接到服务器 | 检查网络连接和防火墙设置 |
| 28 | 请求超时 | 检查网络速度，重试请求 |
| 35 | SSL连接错误 | 检查SSL证书和系统时间 |
| 92 | HTTP/2协议错误 | 使用 `-f` 选项强制HTTP/1.1 |

### 调试技巧
```bash
# 查看详细的curl输出
./get_node_ips.sh -v -f all

# 检查curl版本和支持的协议
curl --version

# 测试基本连接
curl -I https://open.farcdn.net
```

## 🛡️ 安全说明

- 脚本不会存储或传输敏感信息
- 所有网络请求都使用HTTPS加密
- 建议在可信网络环境中运行
- 定期更新curl和系统软件包

## 🔄 更新历史

### v1.2.0 (2025-05-28)
- ✅ 修复统计信息计算问题
- ✅ 改进参数解析逻辑
- ✅ 增强HTTP/2协议兼容性
- ✅ 添加详细的错误提示

### v1.1.0 (2025-05-27)
- ✅ 添加详细输出模式
- ✅ 支持强制HTTP/1.1
- ✅ 改进文件保存功能
- ✅ 增强错误处理

### v1.0.0 (2025-05-27)
- 🎉 初始版本发布
- ✅ 基本IP获取功能
- ✅ 多种IP类型支持
- ✅ 文件导出功能

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个工具！

## 📞 支持

如果你遇到问题或有功能建议，请：

1. 首先查看[常见问题](#❌-错误处理)
2. 使用 `-v` 选项运行脚本获取详细信息
3. 在GitHub上创建Issue

## 🙏 致谢

- [jq](https://stedolan.github.io/jq/) - JSON处理工具
- [curl](https://curl.se/) - 网络请求工具
- 所有为此项目做出贡献的开发者

---

**📝 最后更新**: 2025年5月28日  
**🔖 版本**: v1.2.0  
**👨‍💻 维护者**: FaropenLab

