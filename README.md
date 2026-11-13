# ClaudeAccountFee

一个 macOS 上的 Claude 多账号管理工具：记录账号凭据、订阅付费日志，自动推导账号套餐状态，并按实际付费统计年度费用（人民币）。

## 功能特性

- **账号管理**：邮箱、密码、安全邮箱（可选）、API Key（SK）、KYC 状态、绑定地区、备注
- **加密存储**：主密码 → PBKDF2（31 万次迭代）派生密钥 → AES-256-GCM 加密所有密码类字段；主密码只存加盐哈希，无法反推
- **生物识别解锁**：支持 Touch ID（无指纹机型自动回退为 Mac 登录密码），也可随时用主密码解锁；全局快捷键 ⌘⇧⌥L 一键锁定
- **订阅记录**：每次付费记录套餐（Pro/Max/Ultra）、价格、起止日期（默认当天起 +1 自然月）
- **状态自动推导**：当前套餐由未过期的订阅自动算出，全部过期自动变为 Free；封禁一键标记/解除，自动记录日期
- **年度费用统计**：按订阅记录实际金额汇总，支持年份切换、月度柱状图、按账号明细，可排除已封禁账号
- **便捷操作**：列表右键（编辑 / 添加订阅记录 / 封禁 / 删除）、密码一键复制、按邮箱后缀智能打开邮箱登录页（未知后缀可录入一次永久记住）
- **JSON 导出**：账号数据导出（不含任何密码类字段）

## 系统要求

- macOS 14 (Sonoma) 或更高版本
- Xcode 15+（自行构建）

## 构建

本工程使用 [XcodeGen](https://github.com/yonsm/XcodeGen) 管理工程文件：

```bash
brew install xcodegen   # 如未安装
xcodegen                # 根据 project.yml 生成 .xcodeproj
open ClaudeAccountFee.xcodeproj
```

在 Xcode 中选择 `ClaudeAccount` scheme 运行即可。依赖（KeyboardShortcuts、Pow）通过 Swift Package Manager 自动解析。

## 使用说明

1. 首次启动设置主密码（请务必牢记，忘记后无法找回已存密码，只能重置并清空所有密码字段）
2. 用主密码解锁一次后，即可使用 Touch ID 解锁
3. 点工具栏 **+** 添加账号；双击账号或右键菜单编辑
4. 在编辑页或右键菜单中添加订阅记录，套餐状态、购买日期、年度费用全部自动计算
5. 工具栏锁定按钮或 **⌘⇧⌥L** 随时锁定

## 数据与安全

- 数据库：SwiftData（`~/Library/Application Support/` 下）
- 密码类字段：AES-256-GCM 加密后存入数据库，密钥由主密码经 PBKDF2-HMAC-SHA256（310,000 次迭代）派生，仅在内存中保存
- 生物识别解锁密钥：存于系统钥匙串，标记必须经过用户在场验证（生物识别或设备密码）才能读取
- 主密码哈希与盐：存于 UserDefaults（SHA-256 哈希，不可逆）

## 技术栈

SwiftUI · SwiftData · CryptoKit · LocalAuthentication · Swift Charts · [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) · [Pow](https://github.com/movingparts-io/pow)

## 项目结构

```
ClaudeAccount/
├── App/                 # 应用入口
├── Models/              # ClaudeAccount / SubscriptionRecord 数据模型
├── Services/            # CryptoService（加密/生物识别）、StatsCalculator（统计）
├── Views/               # 界面（侧栏、列表、编辑、统计、锁屏等）
└── Utilities/           # 金额/日期格式化、邮箱登录映射等
project.yml              # XcodeGen 工程定义
```
