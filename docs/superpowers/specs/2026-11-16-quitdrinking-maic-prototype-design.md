# 「破曉戰記（DawnQuest）」戒酒 RPG iOS App 雛形設計規格書

> **文件日期**：2026-11-16  
> **專案目標**：MAIC（Apple 行動應用創新賽）4 人小組開發與 3 分鐘 Keynote 簡報演示用 iOS 原生雛形  
> **實作技術棧**：純 Swift（Swift 6）＋ SwiftUI ＋ SwiftData ＋ Swift Charts ＋ WidgetKit，對齊 Xcode 27.2 / iOS 27.2 SDK 與 Apple HIG  

---

## 1. 核心意圖與解決的問題（Intent & Why）

傳統戒酒／減酒追蹤 App 最大的留存失敗原因有兩個：
1. **過程枯燥缺乏推進感**：只是冷冰冰的天數計數器，使用者很難在日常生活中感受到「今天的忍耐有造成什麼改變」。
2. **「破戒即棄坑」罪惡感循環（What-The-Hell Effect）**：只要有一天忍不住喝了酒，連續天數歸零、進度全毀，使用者出於罪惡感與挫折感就會直接停止開啟甚至刪除 App。

本專案透過 **RPG 打怪晉級** 改寫這個體驗，同時針對 **MAIC 賽制（3 分鐘簡報演示、不現場實操 App）** 設計，將重心聚焦在最能打動評審、且最方便團隊錄製 60fps 高畫質操作影片放入 Keynote 的「黃金三畫面」與 iOS 生態系整合：
* **沒喝＝攻擊怪物扣血（並晉級解鎖更強關卡）**，將每一天的忍耐視覺化為具體推進感。
* **有喝＝觸發「誠實護盾」而非清零懲罰**，誠實記錄誘因即可擋下大部分反撲，怪物只會微幅回血（有上限、不倒退關卡），把挫敗轉化為自我覺察的「反省經驗值」。
* **真實世界價值換算**：將打怪造成的累積傷害即時換算成「省下的酒錢（NT$）」與「少攝取的熱量（相當於幾碗白飯）」。

---

## 2. 目標、非目標與反目標

### 目標（Goals — 本次雛形必須做到）
1. **可於 Xcode 建置並於模擬器／實機運行的原生 iOS App 雛形**（含主 App 與 Widget Extension 兩個 Target）。
2. **雙軌目標模式**：「完全斷酒（Strict Abstinence）」與「減量控酒（Moderation Budget，可設每週安全額度）」，可於個人化設定／引導頁切換。
3. **完整單機 RPG 戰鬥與晉級迴圈**：
   * 4 隻階段性怪獸關卡（含動態血條、受傷震動與飄浮傷害數字、擊敗晉級全螢幕慶祝動效）。
   * 「今天有喝」誠實護盾流程（選取喝酒誘因標籤、杯數，觸發護盾動畫與微幅上限回血）。
   * 以 **SwiftData** 持久化儲存戰鬥進度與每日打卡紀錄。
4. **黃金三畫面與 Swift Charts 戰績分析**：累計省錢／熱量換算、7 日傷害趨勢長條圖、誠實護盾誘因分佈統計與怪獸圖鑑。
5. **WidgetKit 桌面／鎖定畫面小工具**：在系統主畫面與鎖定畫面顯示當前怪獸狀態與血條進度，展現 Apple 生態系整合亮點。
6. **MAIC Demo 模擬控制台**：內建可收合的快速狀態切換器（一鍵切換滿血、殘血即將擊敗、誠實護盾待命、一週豐富戰績），並支援「純淨錄影模式」隱藏控制按鈕，方便直接錄製 60fps 影片給 Keynote 使用。
7. **4 人協作友善的模組化資料夾架構**：對應 4 位組員的分工邊界，後續可搭配 `/skill-creator` 建立團隊專屬開發 Skill（`.agents/skills/quitdrinking-maic-rules/`）。

### 非目標（Non-Goals — 本次雛形刻意不做）
* 帳號註冊、登入驗證、後端伺服器、CloudKit 雲端同步或多人連線排行榜。
* 推播伺服器或複雜的排程提醒設定頁（僅保留本地結構擴充點）。
* Apple Watch 獨立 Target 或 HealthKit 寫入授權流程（保留介面擴充點，避免初版簽章與權限彈窗打斷 Demo 錄影）。
* 手繪點陣圖或 3D 模型外部資源依賴（初版以高質感 SwiftUI 向量幾何圖形與 SF Symbols 組合呈現怪獸並預留圖片替換點，待組員完成美術素材後可直接替換）。

### 反目標（Anti-Goals — 即使程式可跑也算失敗的紅線）
* **懲罰性歸零**：任何情況下都不能因為使用者記錄了一次喝酒，就把關卡等級倒退或把累計省錢／健康成果歸零。
* **模板化 SaaS 堆砌感**：不出現千篇一律的灰底圓角方塊列表、過度擁擠的數據文字或無意義的裝飾漸層；畫面必須在手機上看起來像精緻的獨立遊戲兼健康工具，放進 Keynote 簡報框後依然一眼可讀。
* **卡頓或不可控的動畫**：不對大型容器做連續 Layout 重算或高耗能大面積動態模糊；所有轉場尊重系統 `accessibilityReduceMotion` 設定，主操作按鈕回饋延遲不超過 200ms。

---

## 3. 技術限制與環境對齊

* **開發語言與框架**：100% **Swift + SwiftUI**（不引入 UIKit / AppKit 視圖控制器或第三方 UI 框架）。
* **系統與 SDK 版本**：本機環境為 **Xcode 27.2（Build 27B52）**、**Swift 6.4.2**、**iOS 27.2 SDK**，預設 `IPHONEOS_DEPLOYMENT_TARGET = 27.2`（若後續組員實機系統為較舊版本，可於專案設定調降並補上對應 availability 檢查）。
* **Apple HIG 與無障礙規範**：
  * 使用系統圓角字體 `.rounded` 搭配 `.monospacedDigit()` 呈現所有血量、金額與天數數值，避免數字變動時版面抖動。
  * 所有純圖示按鈕與自繪怪獸血條皆提供明確的 `accessibilityLabel` 與 `accessibilityValue`。
  * 使用 SwiftUI 原生 `.sensoryFeedback(...)` 提供攻擊打擊感與護盾觸發的觸覺震動回饋。
* **Widget 資料共享與簽章安全降級**：
  * 主 App 與 `QuitDrinkingWidget` 透過 App Group（`group.com.quitdrinking.app`）中的輕量 JSON 快照（`UserDefaults(suiteName:)`）同步當前怪獸名稱、等級、現有血量、最大血量與連勝天數。
  * **實作降級機制**：若執行於未開通 App Group Capability 的個人免費簽章或純 Preview 環境，`SharedSnapshotStore` 自動退回至 `UserDefaults.standard` 讀取本地資料並提供預設預覽快照，確保小工具在任何電腦打開都能編譯與顯示，不因 Entitlement 問題報錯。

---

## 4. 方案選擇紀錄（Approaches）

| 方案 | 說明 | 取捨 | 決策 |
| :--- | :--- | :--- | :--- |
| **方案 A（選定）** | 直上原生 SwiftUI 黃金三畫面雛形 ＋ MAIC Demo 模擬控制台 | 美術先以 SwiftUI 向量／SF Symbols 佔位，換取最快得到可操作、可 60fps 錄影進 Keynote 的真實 App | **採用** |
| **方案 B** | 先透過 Sleek 裝置授權產出視覺稿，再轉譯為 SwiftUI | 視覺定調直觀，但需外部帳號登入與額度等待，無法立即產生 Xcode 程式碼 | 暫不採用（未來美術深化可輔助參考） |
| **方案 C** | 僅建置資料層骨架與專案 Skill，UI 維持極簡線框 | 分工邊界清晰，但視覺張力不足以錄製 MAIC 簡報演示片段 | 暫不採用（但於方案 A 內直接採用同樣清晰的模組切分，並於初版完成後用 `/skill-creator` 補齊專案 Skill） |

---

## 5. 遊戲機制與數值規則（已拍板預設）

### 5.1 雙軌目標模式（`GoalMode`）
* **完全斷酒（`strictAbstinence`）**：
  * 打卡「今日沒喝」→ 發動攻擊扣減怪獸血量，並累積連勝天數（Streak）。
  * 打卡「今天有喝」→ 觸發誠實護盾（微幅回血、不倒退關卡、不歸零終身戰績），當前連勝天數歸零重算但保留「誠實護盾次數」與「反省經驗值」。
* **減量控酒（`moderationBudget`）**：
  * 使用者可設定「每週安全喝酒額度」（預設每週 2 次 / 4 標準杯）。
  * 打卡「今日沒喝」→ 發動標準重擊（100+ 傷害）。
  * 打卡「今天有喝」且**未超過本週額度**→ 不視為破戒！顯示「額度內理性小酌」，僅發動輕量防禦（不回血，或僅怪物護甲小幅回復 `15 HP`），連勝週數照常累積。
  * 打卡「今天有喝」且**超過本週額度**→ 觸發「誠實護盾」機制並計入誘因分析。

### 5.2 怪獸關卡與晉級曲線（`MonsterCatalog`）
共設計 4 隻主題怪獸，血量對應戒酒關鍵里程碑（3 天、7 天、14 天、30 天）：

| 等級 | 怪獸名稱 | 最大血量 (Max HP) | 設計對應天數 | 主題色／視覺意象 | 擊敗稱號獎勵 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Lv.1** | **微醺史萊姆** | `300 HP` | 約 3 天 | 琥珀半透明氣泡史萊姆 | 清醒見習生 |
| **Lv.2** | **啤酒肚哥布林** | `700 HP` | 約 7 天 | 手持酒杯的頑皮重裝怪 | 聚餐防禦者 |
| **Lv.3** | **宿醉巨龍** | `1,400 HP` | 約 14 天 | 紫紅吐息與黑曜鱗甲 | 自律騎士 |
| **Lv.4** | **心魔魔王** | `3,000 HP` | 約 30 天 | 暗夜紫金皇冠與裂痕護盾 | 破曉勇者 |

* 通關 Lv.4 後進入「無盡破曉守護者（Endless Tier）」循環挑戰或可於圖鑑重溫所有戰役，確保長期使用不卡死。

### 5.3 攻擊與誠實護盾公式（`CombatEngine`）
* **攻擊傷害（沒喝）**：
  * 基礎傷害 = `100 HP`
  * 連擊加成（Combo Bonus）= `min(currentStreak * 10, 50)`（連勝第 5 天起固定暴擊 `150 HP`）
  * 總傷害 = `100 + min(currentStreak * 10, 50)`
  * 若扣血後 `currentHP <= 0`：觸發**擊敗怪獸晉級流程**，溢出傷害不浪費（可視為下隻怪獸的開場先制重擊，或歸零後滿血迎戰下一隻——**建築師決策：下一隻怪獸以滿血登場，讓新關卡儀式感與血條視覺最清楚，適合簡報展示**）。
* **誠實護盾回血（超標有喝）**：
  * 誘因標籤（至少選 1 個，支援複選）：`聚餐應酬`、`工作課業壓力`、`朋友起鬨`、`心情低落`、`慶祝開心`、`睡前習慣`。
  * 回血計算：`healAmount = min(units * 45, Int(Double(maxHP) * 0.20))`（單次上限鎖在最大血量的 20%）。
  * 限制邊界：`newHP = min(maxHP, currentHP + healAmount)`，**絕對不會回溢退回上一隻怪獸**。
  * 玩家獎勵：`honestShieldCount += 1`、`insightXP += 25`（鼓勵誠實紀錄並留下誘因資料）。

### 5.4 現實成果換算基準（`ImpactMetrics`）
* 預設每次成功避開飲酒省下：**NT$ 250**（約一杯精釀啤酒或超商調酒組合）、**420 kcal**（約 **1.5 碗白飯**，以每碗 280 kcal 換算）。
* 提供輕量調整設定（可於戰績頁右上角調整「平均單次酒錢」與「平均單次熱量」），立刻反映在所有累計換算上。

### 5.5 打卡冷卻與「Demo 模式不卡關」設計
* 正式產品通常每日限制 1 次主打卡，但在 MAIC 雛形與組員測試階段，若點一次就被鎖住 24 小時會非常難錄製展示影片。
* 因此在雛形中預設開啟 **「Demo 快速演練模式（允許連續打卡測試）」**，同時在右上角 Demo 控制台提供「嚴格每日一次鎖定」切換開關，兼顧測試演示流暢度與真實產品邏輯驗證。

---

## 6. 視覺系統與黃金三畫面線框（Visual & UI Design）

### 6.1 美學方向：「暗夜酒館 → 清晨破曉（Twilight Tavern to Crisp Dawn）」
放棄常見的白底醫療感與雜亂霓虹手遊風，採用高對比的深邃夜幕底色，讓角色與動效在 Keynote 手機樣機中成為視覺絕對焦點：
* **背景畫布**：深夜石板藍 `#0D131F` / 卡片微浮層 `#162032`（1px 細緻微光邊框 `white.opacity(0.08)`）
* **主要文字**：暖象牙白 `#F6F3EC` / 次要說明霧灰 `#94A3B8`
* **主行動／清醒活力色（Attack & Savings）**：破曉薄荷綠 `#2DD4BF`（代表清醒傷害與健康收益）
* **誠實護盾／晉級榮耀色（Shield & Level Up）**：琥珀金 `#F59E0B`（代表防護盾、連擊與勳章）
* **警戒／破戒回血色（Monster Heal / Crit）**：珊瑚緋紅 `#F43F5E`（僅用於傷害數字與怪物回血警示）

### 6.2 畫面結構與佈局（3-Tab 架構）

```text
+-----------------------------------+
|  DawnQuest   [減量 1/2]   [Demo*] |  <- *純淨錄影模式可隱藏 [Demo]
+-----------------------------------+
|                                   |
|      Lv.2  啤酒肚哥布林            |
|   ============================    |
|     HP  420 / 700  (-120 暴擊!)   |
|                                   |
|          ( 怪獸動畫舞台 )          |  <- 佔畫面 ~52%，點擊攻擊有
|          [  Lv.2 Monster  ]       |     震動、閃白與傷害數字飛出
|                                   |
|  連勝 3 天 (+30 暴擊) | 護盾 2 次  |
+-----------------------------------+
|  [  今日沒喝・發動攻擊 (-130)  ]   |  <- 主 CTA（薄荷綠實心）
|  [  今天有喝・開啟誠實護盾     ]   |  <- 次 CTA（琥珀金描邊）
+-----------------------------------+
|  [戰場]      [戰績]      [圖鑑]    |  <- 原生 TabView
+-----------------------------------+
```

#### 分頁一：主戰場（`BattleArenaView`）
* **頂部狀態列**：目前目標模式膠囊（點擊可切換斷酒／減量並看本週額度進度）、右上角 Demo 控制台按鈕（開啟純淨模式後改以長按標題觸發，確保錄影畫面零雜訊）。
* **怪獸舞台**：
  * 怪物圖像隨血量百分比呈現狀態變化（高血量囂張晃動、低血量虛弱閃爍裂痕）。
  * 使用 SwiftUI `PhaseAnimator` / Spring 動效呈現受擊後退、傷害數字上飄淡出、以及「誠實護盾」開啟時的半透明琥珀護盾罩展開效果。
* **晉級慶祝覆蓋層（`LevelUpCelebrationView`）**：擊敗怪獸瞬間全螢幕呈現稱號解鎖卡片與下一隻怪獸登場預告，按「迎戰下一關」無縫接續（非常適合 Keynote 錄影展示高潮）。

#### 分頁二：戰績與價值換算（`InsightsDashboardView`）
* **Hero 換算雙卡**：醒目顯示「累積省下 NT\$ X,XXX」與「少攝取 X,XXX 大卡（約 X.X 碗白飯）」。
* **Swift Charts 近 7 日戰鬥趨勢圖**：以 `BarMark` 區分清醒攻擊日（薄荷綠）與誠實護盾日（琥珀金），直觀展現即使偶有小酌，整體累積仍是正向推進。
* **喝酒誘因雷達／排行條**：統計使用者在誠實護盾中勾選最多的情境標籤（例如「聚餐應酬 60%」），作為 MAIC 簡報中「端側行為洞察」的視覺佐證。

#### 分頁三：怪獸圖鑑與里程碑（`MonsterBestiaryView`）
* 以 2 欄卡片或縱向推進時間軸列出 Lv.1～Lv.4 怪獸，清楚區分「已擊敗（顯示獲得稱號與擊敗天數）」、「交戰中（顯示剩餘血量）」與「未解鎖（神秘剪影＋解鎖條件）」。

---

## 7. 團隊分工導向的檔案結構（Project Structure）

依照你們 4 位組員的角色切分資料夾，減少未來 Git 合併衝突：

```text
QuitDrinking/
├── QuitDrinking.xcodeproj/
├── QuitDrinking/                         # 主 iOS App Target
│   ├── App/
│   │   └── QuitDrinkingApp.swift         # App 入口與 SwiftData ModelContainer 設定
│   ├── DesignSystem/                     # 共用視覺規範（色彩、字體、按鈕樣式）
│   │   ├── ThemeTokens.swift
│   │   └── TactileButtonStyles.swift
│   ├── Domain/                           # 【組員 1：核心邏輯與資料層】
│   │   ├── Models.swift                  # SwiftData @Model (PlayerProgress, CheckInRecord)
│   │   ├── MonsterCatalog.swift          # 4 隻怪獸定義與屬性
│   │   ├── CombatEngine.swift            # 攻擊、暴擊、減量額度與誠實護盾運算
│   │   └── SharedSnapshotStore.swift     # App Group <-> Widget 狀態同步與安全降級
│   ├── Features/
│   │   ├── Battle/                       # 【組員 2：主戰場與動畫體驗】
│   │   │   ├── BattleArenaView.swift
│   │   │   ├── MonsterAvatarView.swift   # 向量怪獸造型與受擊/護盾視覺狀態
│   │   │   ├── HonestShieldSheet.swift   # 誠實紀錄表單（誘因標籤與杯數）
│   │   │   └── LevelUpCelebrationView.swift
│   │   ├── Insights/                     # 【組員 3：戰績圖表與怪獸圖鑑】
│   │   │   ├── InsightsDashboardView.swift
│   │   │   └── MonsterBestiaryView.swift
│   │   └── Demo/                         # 【組員 4：MAIC 簡報與系統整合】
│   │       └── MAICDemoSheet.swift       # 簡報錄影預設狀態切換、純淨模式與基準設定
│   └── RootTabView.swift
├── QuitDrinkingWidget/                   # 【組員 4：WidgetKit 延伸 Target】
│   ├── QuitDrinkingWidgetBundle.swift
│   └── MonsterStatusWidget.swift         # 支援 systemSmall / systemMedium / accessoryRectangular
└── docs/
    └── superpowers/specs/
        └── 2026-11-16-quitdrinking-maic-prototype-design.md
```

---

## 8. `/skill-creator` 後續整合規劃

在本初版 App 建置與模擬器驗證完成後，將運用 `/skill-creator` 在專案內建立 `.agents/skills/quitdrinking-maic-rules/SKILL.md`（透過 Git 分享給 4 位組員），規範：
* 怪獸血量、傷害、護盾回血與防倒退公式的不可變規則。
* `ThemeTokens` 語意色票與禁止使用 UIKit / 懲罰歸零機制的防護守則。
* 4 人模組的檔案編輯邊界與 MAIC Demo 狀態管理約定。

---

## 9. 留待實作階段決策的細節（Left to Builder）
* Xcode `.xcodeproj` 具體 UUID、Build Settings 與 Info.plist（Widget Extension Point 與 App Group Entitlements 設定）。
* SwiftUI 怪獸向量幾何路徑（`Shape` / `Canvas` / SF Symbols 層疊細節）與精確的 Spring 阻尼參數。
* 使用本機 iOS Simulator（或已連線 iOS 實機）進行建置、安裝與截圖／操作驗證的具體流程。
