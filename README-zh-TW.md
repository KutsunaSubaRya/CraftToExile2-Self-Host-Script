# CraftToExile2 伺服器端自動化腳本

*此文章也有 [原文(英文 English)](README.md)。*

一套完整的自動化套件，用於自架 CraftToExile2 Minecraft 伺服器，具備自動化管理、監控和維護功能。

## 概述

本專案提供完整腳本，講述透過 cron 排程自動化管理 Minecraft CraftToExile2 Mod Server Pack 伺服器、MC Server 啟動、Cloudflare 通道管理、效能監控、日誌歸檔和優雅的伺服器重啟。

**注意**: **雖然本文件基本上顯示全中文，但多數設定詞與 server 端設定檔案皆是使用英文做設定的，並且作者我是用英文文件搭配 AI 翻譯此文件成中文 (嘿嘿，跟大多數人相反吧 www)，還請搭配 README.md 觀看。**

**目標受眾**：目前本專案是為 8 人同時在線的小型到中型社群而設計。此自動化套件為想要實作自動化管理和監控系統的自架模組化 Minecraft 伺服器管理員提供參考腳本。

## 快速開始注意事項

**注意事項**：正式使用這些腳本前，請詳讀本文件並請在原始碼中使用 `Ctrl + F`（或在 macOS 上使用 `Cmd + F`）搜尋 `TODO` 註解，以為您的環境做初始設定與客製化。例如：
- RCON 密碼
- 網域名稱
- 檔案路徑
- 伺服器特定設定

**RCON 配置**：確保您的 `server.properties` 檔案中 `rcon.password=` 已設定為您想要的密碼，這是監控和重啟腳本正常運作的**必要條件**。

## 推薦配置

### 模組與本體版本
- **CraftToExile2**：1.0.5
- **Forge**：47.4.4
- **Minecraft**：1.20.1

### 硬體規格
- **CPU**：4 核心
- **RAM**：14 GB
- **環境**：PVE VM（Proxmox 虛擬環境）

**注意**：此配置已測試並優化以獲得最佳效能。雖然腳本可在其他配置上運作，但此設定為 8+ 同時在線玩家的模組化 Minecraft 伺服器提供的基準，可以根據維運與您的客群數的變化而動態調整本腳本。

## 工作流程

系統透過 cron 工作管理的協調工作流程運作：

1. **通道**：Cron 在啟動時立即觸發 `cloudflared_tunnel_start.sh`
2. **延遲伺服器啟動**：15 秒後執行 `start.sh` 啟動 Minecraft 伺服器
3. **順序執行**：通道建立先於伺服器啟動，確保外部連線就緒
4. **持續運作**：伺服器持續運行，具備自動化監控和維護
5. **排程任務**：透過 cron 進行定期健康檢查、日誌歸檔和效能監控

## 腳本概覽

| 腳本 | 目的 | Cron 排程 | 描述 |
|------|------|------------|------|
| `start.sh` | Minecraft 伺服器啟動器 | 伺服器啟動時 | 在命名 `screen` 中初始化和啟動 Minecraft 伺服器 |
| `cloudflared_tunnel_start.sh` | 通道管理器 | 伺服器啟動時 | 建立 Cloudflare 通道供外部伺服器存取 |
| `rcon-spark.sh` | 效能監控器 | 每 5 分鐘 | 收集伺服器效能指標和健康資料 |
| `archive-logs.sh` | 日誌管理 | 每日 | 歸檔舊日誌檔案並維護備份輪換 |
| `mc-restart.sh` | 伺服器控制 | 手動/每六小時 | 處理優雅的伺服器重啟，具備倒數通知 |

## 依賴項目

- **`screen`**：用於背景程序管理的終端多工器
- **`cloudflared`**：Cloudflare 通道用戶端，供外部存取
- **`mcrcon`**：RCON 用戶端，用於 Minecraft 伺服器通訊
- **`zip/tar`**：用於日誌壓縮的歸檔工具
- **`openjdk-21-jdk`**

## JVM 配置

`user_jvm_args.txt` 檔案包含針對模組化 Minecraft 伺服器優化的 JVM 參數：

### 記憶體管理
- `-Xms10G -Xmx12G`：分別設定初始和最大堆積大小為 10GB 和 12GB
- `-XX:+UseG1GC`：啟用 G1 垃圾收集器以獲得更好效能
- `-XX:+ParallelRefProcEnabled`：啟用並行參考處理

### 垃圾收集調校
- `-XX:MaxGCPauseMillis=200`：目標最大 GC 暫停時間為 200ms
- `-XX:G1NewSizePercent=20`：設定新世代大小為堆積的 20%
- `-XX:G1MaxNewSizePercent=60`：限制新世代為堆積的 60%
- `-XX:G1ReservePercent=20`：保留堆積的 20% 以防止配置失敗
- `-XX:InitiatingHeapOccupancyPercent=15`：當堆積的 15% 被佔用時觸發 GC

### 效能優化
- `-XX:+UseStringDeduplication`：透過字串去重複減少記憶體使用
- `-XX:+DisableExplicitGC`：防止手動垃圾收集呼叫
- `-XX:+UnlockExperimentalVMOptions`：啟用實驗性 JVM 功能

### 監控和分析
- `-Xlog:gc*`：啟用全面的垃圾收集日誌記錄
- `-XX:StartFlightRecording`：啟動 Java Flight Recorder 進行效能分析
- `-XX:FlightRecorderOptions=stackdepth=128`：設定分析用的堆疊深度

## 腳本詳情

### start.sh

**目的**：主要伺服器啟動器，初始化 Minecraft 伺服器環境。

**主要功能**：
- 在 `logs/` 目錄中建立時間戳記日誌檔案
- 透過檢查現有 `screen` session 防止重複伺服器實例
- 使用 `stdbuf` 進行即時日誌輸出緩衝
- 在名為 'mc' 的離線 `screen` session 中啟動伺服器

**Cron 整合**：在伺服器啟動時觸發以確保自動伺服器啟動。

**技術細節**：
- 使用 `set -euo pipefail` 進行嚴格錯誤處理
- 如果不存在則建立 logs 目錄
- 以時間戳記格式產生唯一日誌檔名：`latest-YYYYMMDD-HHMM.log`
- 實作 `screen` session 衝突偵測

### cloudflared_tunnel_start.sh

**目的**：建立和維護 Cloudflare 通道供外部伺服器存取。

**主要功能**：
- 為您的網域建立 DNS 路由
- 建立到本地 Minecraft 伺服器的 TCP 通道（例如預設連接埠 25565）
- 在名為 'tunnel' 的背景 `screen` session 中執行

**Cron 整合**：在伺服器啟動時執行以確保通道可用性。

**技術細節**：
- 結合 DNS 路由和通道建立的單行腳本
- 使用 `screen -dmS` 進行背景執行
- 透過 Cloudflare 基礎設施連接外部網域到本地伺服器

### rcon-spark.sh

**目的**：全面的伺服器監控和效能資料收集。

**主要功能**：
- 收集即時玩家數量和伺服器統計資料
- 追蹤伺服器屬性和視野距離設定
- 執行 Spark 分析指令進行效能分析
- 監控 JVM 記憶體使用和配置

**Cron 整合**：每 5 分鐘執行一次以進行持續健康監控。

**技術細節**：
- 實作 RCON 連線重試邏輯（6 次嘗試，10 秒間隔）
- 擷取 Spark 指令結果的主控台輸出變更
- 從執行中程序或命令列擷取 JVM 參數
- 產生具時間戳記條目的每日日誌檔案
- 使用 `dd` 指令進行精確日誌區段擷取

### archive-logs.sh

**目的**：自動化日誌檔案管理和歸檔系統。

**主要功能**：
- 歸檔超過 5 分鐘的非活躍日誌檔案（防止壓縮正在寫入的檔案）
- 維護備份輪換（保留最新 14 個歸檔 - 保留 2 週）
- 支援 ZIP 和 TAR 壓縮格式
- 排除活躍主控台和當日日誌

**Cron 整合**：每日執行以維持日誌儲存效率。

**技術細節**：
- 使用 `find` 和 `-mmin +5` 識別非活躍檔案（最後修改後 5+ 分鐘）
- 實作智慧過濾以保留活躍日誌
- 成功壓縮後自動移除已歸檔檔案
- 如果 zip 工具不可用則退回 tar.gz
- 實作備份保留政策以防止無限成長
- **5 分鐘延遲策略**：防止壓縮正在寫入的檔案，例如：
  - 被 `tee` 寫入的當前主控台日誌（`latest-*.log`）
  - 每 5 分鐘更新的當日 Spark 日誌（`spark-YYYYMMDD.log`）
  - 由 JVM 產生的活躍 JFR/GC 日誌

### mc-restart.sh

**目的**：優雅的伺服器重啟管理，具備玩家通知。

**主要功能**：
- 提供手動執行
- 多種重啟模式（5 分鐘、30 秒、15 秒、立即關服不重啟）
- 遊戲內倒數通知，具備音效
- 單一實例鎖定以防止 cron 衝突
- 關機後自動伺服器重啟
- 內建說明系統，具備 `--help` 標記
- 輸入驗證和未知選項的錯誤處理

**Cron 整合**：預設是透過 crontab 每六小時觸發此腳本。


**技術細節**：
- 使用 `flock` 防止單一實例執行
- 實作基於 RCON 的遊戲內訊息系統
- 支援自訂通知前綴和音效
- 處理重啟和關機模式
- 伺服器停止後自動執行 `start.sh`
- **說明系統**：提供 `--help`、`-h`、`help` 標記的全面使用資訊
- **輸入驗證**：自動偵測未知選項並顯示說明
- **錯誤處理**：優雅地處理無效輸入並提供有用的錯誤訊息

## Cron 配置

自動化運作的推薦 cron 排程：

```bash
# 伺服器啟動（啟動時）
@reboot /path/to/cloudflared_tunnel_start.sh
@reboot sleep 15 && /path/to/start.sh

# 每 6 小時重啟
0 */6 * * * /path/to/mc-restart.sh

# 效能監控（每 15 分鐘）
*/15 * * * * /path/to/rcon-spark.sh

# 日誌歸檔（每日凌晨 4 點）
0 4 * * * /path/to/archive-logs.sh
```

**注意**：通道和伺服器啟動之間的 15 秒延遲確保：
- Cloudflare 通道在 Minecraft 伺服器開始前完全建立
- 當玩家嘗試連線時外部連線已準備就緒
- 防止初始伺服器啟動階段的連線問題

## 檔案結構

```
yourMCDirectory/
├── start.sh                    # 伺服器啟動器
├── cloudflared_tunnel_start.sh # 通道管理器
├── rcon-spark.sh              # 效能監控器
├── archive-logs.sh            # 日誌歸檔器
├── mc-restart.sh              # 伺服器控制器
├── user_jvm_args.txt          # JVM 優化參數
└── README.md                  # 此文件
```

## 故障排除

- **伺服器無法啟動**：檢查 `screen` session 衝突和日誌檔案權限
- **RCON 失敗**：確保伺服器正在執行且 RCON 已啟用
- **日誌歸檔失敗**：檢查可用磁碟空間和壓縮工具

## 其他維護

### 即時日誌監控
使用 tail 即時監控伺服器日誌：
```bash
tail -f logs/latest-*.log
```

### 檢查在線玩家數量
使用 mcrcon 查詢當前在線玩家：
```bash
/usr/bin/mcrcon -H 127.0.0.1 -P 25575 -p 'yourPassword' "list"
```

### 其他檢查方法
* 檢查其他 log 的內容進行判斷
  * gc-*.log
  * jfr-*.jfr
    * 把 jfr 用 CLI 工具或是 scp 到你的 Windows 使用 JMC 工具查看

**注意**：將 `yourPassword` 替換為您的實際 RCON 密碼。預設 mcrcon 路徑為 `/usr/bin/mcrcon`，但您可以使用 `which mcrcon` 驗證正確路徑。
