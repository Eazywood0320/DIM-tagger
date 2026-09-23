# DIM-tagger

[中文说明](#中文说明) · [English](#english)

---

## 中文说明

根据 [Starside](https://starside.work/) 的《命运 2》PVE 购物清单，为玩家拥有的武器自动写入 Destiny Item Manager（DIM）标签。

### 标签规则

| 购物清单匹配情况 | DIM 标签 |
| --- | --- |
| 四个 Perk 位全部符合 | Archive / 归档 |
| 第 3、4 位符合，且第 1、2 位至少一项符合 | Favorite / 青睐 |
| 第 3、4 位同时符合 | Keep / 保留 |
| 其他情况 | Junk / 垃圾 |

异域武器和锻造武器不会被添加标签；如果原来存在标签，工具会清除该标签。已有 DIM 备注会保留。

### 使用方法

1. 点击仓库右上方 `Code` → `Download ZIP`，下载后完整解压。
2. 双击 `Run.cmd`。
3. 阅读弹出的配置说明与密钥获取教程。
4. 按教程准备并输入 Bungie API Key、OAuth Client ID、OAuth Client Secret、DIM API Key 和 DIM Origin。
5. 在浏览器中登录并授权 Bungie，等待 Starside 清单更新和标签同步完成。

`Tutorial.cmd` 可以随时单独打开教程。

### 其他入口

- `Preview.cmd`：只预览分类结果，不修改 DIM 标签。
- `Apply-Tags.cmd`：执行标签同步。
- `Update-Now.cmd`：只检查 Starside 最新购物清单。
- `Self-Test.cmd`：执行离线兼容性和分类逻辑检查。
- `Reset-Login.cmd`：清除本机保存的配置和 OAuth 登录状态。

### 运行要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1
- 可访问 Bungie、DIM 和 Starside 的网络
- Bungie 与 DIM 开发者应用信息

不需要安装 Python、Node.js、Git 或额外 PowerShell 模块。

### 隐私与安全

- API 配置和 OAuth 令牌保存在本地 `state` 文件夹中。
- 敏感值使用 Windows DPAPI 加密，只能由当前电脑的当前 Windows 用户解密。
- `state`、运行日志和 CSV 报告不会被 Git 跟踪。
- 不要分享自己的 Client Secret、API Key、OAuth 令牌或 `state` 文件夹。

### 免责声明

本项目与 Bungie、Destiny Item Manager 和 Starside 无隶属或官方合作关系。《命运 2》及相关商标归其权利人所有。

---

## English

Automatically applies Destiny Item Manager (DIM) tags to owned weapons using the Destiny 2 PVE shopping lists published by [Starside](https://starside.work/).

### Tagging rules

| Shopping-list match | DIM tag |
| --- | --- |
| All four perk columns match | Archive |
| Columns 3 and 4 match, plus either column 1 or 2 | Favorite |
| Both columns 3 and 4 match | Keep |
| Any other result | Junk |

Exotic and crafted weapons are left untagged. If either already has a DIM tag, the tool clears that tag. Existing DIM notes are preserved.

### Getting started

1. Select `Code` → `Download ZIP` in the upper-right corner of the repository, then fully extract the archive.
2. Double-click `Run.cmd`.
3. Read the built-in setup and API-key tutorial.
4. Follow the tutorial to obtain and enter your Bungie API Key, OAuth Client ID, OAuth Client Secret, DIM API Key, and DIM Origin.
5. Sign in to Bungie in your browser, approve access, and wait for the Starside list update and DIM tag synchronization to finish.

You can reopen the setup tutorial at any time by running `Tutorial.cmd`.

### Other launchers

- `Preview.cmd`: Preview classifications without changing DIM tags.
- `Apply-Tags.cmd`: Apply tag synchronization.
- `Update-Now.cmd`: Check only for the latest Starside shopping lists.
- `Self-Test.cmd`: Run offline compatibility and classification tests.
- `Reset-Login.cmd`: Delete the locally saved configuration and OAuth session.

### Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- Network access to Bungie, DIM, and Starside
- Bungie and DIM developer application credentials

Python, Node.js, Git, and additional PowerShell modules are not required.

### Privacy and security

- API configuration and OAuth tokens are stored in the local `state` directory.
- Sensitive values are encrypted with Windows DPAPI and can only be decrypted by the same Windows user on the same computer.
- The `state` directory, runtime logs, and CSV reports are excluded from Git.
- Never share your Client Secret, API keys, OAuth tokens, or `state` directory.

### Disclaimer

This project is not affiliated with or endorsed by Bungie, Destiny Item Manager, or Starside. Destiny 2 and all related trademarks belong to their respective owners.
