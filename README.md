# v2ray-agent

- [感谢 JetBrains 提供的非商业开源软件开发授权](https://www.jetbrains.com/?from=v2ray-agent)

Xray-core/sing-box 一键脚本快速安装

## 功能

*   **多核心支持:** 支持 Xray-core 和 sing-box.
*   **多协议支持:** 支持 VLESS, VMess, Trojan, Hysteria2, Tuic, NaiveProxy 等多种协议.
*   **自动TLS:** 自动申请和续订 SSL 证书.
*   **易于管理:** 提供简单的菜单来管理用户、端口和配置.
*   **订阅支持:** 生成和管理订阅链接.
*   **分流管理:** 提供wireguard、IPv6、Socks5、DNS、VMess(ws)、SNI反向代理，可用于解锁流媒体、规避IP验证等作用.
*   **目标域名管理:** 提供域名黑名单管理，可用于禁止访问指定网站.
*   **BT下载管理:** 可用于禁止下载P2P相关内容.

## 快速开始

### 安装

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/sundys/v2ray/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

### 使用

安装后，运行以下命令可再次打开管理菜单:

```
vasma
```

## 许可证

本项根据 [AGPL-3.0 许可证](LICENSE) 授权.
