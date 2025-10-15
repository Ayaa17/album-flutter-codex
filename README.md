## 📸 Flutter 活動相簿 App

> **本專案部分程式碼由 [OpenAI Codex](https://openai.com/research/codex) 協助生成與優化。**
> A beautifully designed Flutter app for capturing, organizing, and browsing event-based photo albums on iOS and Android.

---

### 🧩 專案簡介

這是一款以 **活動為單位** 管理照片的 Flutter 相簿應用。
使用者可以建立活動（預設名稱為日期），拍照或新增照片，
並在活動內瀏覽、管理所有影像。
整體 UI 採用現代設計風格，兼顧 **易用性** 與 **流暢體驗**。

---

### ✨ 主要功能

* 🗓️ 建立活動（預設為日期，可自訂）
* 📷 拍照並自動歸類至當前活動
* 🖼️ 檢視特定活動中的所有照片
* 💾 照片以活動為單位儲存於本地
* 🎨 精美介面、流暢互動體驗（支援 iOS / Android）

---

### 🧱 專案架構

```
lib/
│  main.dart
├─app
│      event_album_app.dart
├─models
│      event.dart
├─repositories
│      event_repository.dart
├─viewmodels
│      event_detail_view_model.dart
│      event_list_view_model.dart
├─views
│      event_detail_page.dart
│      event_list_page.dart
└─widgets
        event_card.dart
```

**架構風格**：MVVM + Repository
**設計目的**：保持邏輯分離、易於維護與擴充。

---

### 🛠️ 使用技術

| 類別               | 技術                                                                  |
| ---------------- | ------------------------------------------------------------------- |
| Framework        | Flutter (Stable Channel)                                            |
| Language         | Dart                                                                |
| Architecture     | MVVM + Repository                                                   |
| State Management | Provider / ChangeNotifier                                           |
| Plugins          | `image_picker`, `path_provider`, `flutter_plugin_android_lifecycle` |
| Platforms        | iOS / Android                                                       |

---

### 🧠 關於 OpenAI Codex

> 本專案的結構設計與部分程式碼，
> 由 **OpenAI Codex** 模型協助生成與重構。
> Codex 是 OpenAI 的 AI 程式開發模型，
> 能理解自然語言指令並生成高品質可執行程式碼，
> 是 GPT-5 技術在軟體開發領域的重要應用之一。

---

### ⚠️ 版權與授權聲明

本專案 **不對外開放授權**。
禁止未經許可的：

* 原始碼重製、散佈或修改
* 部分或全部內容轉載
* 用於商業或再開發用途

> 版權所有 © 2025 — 本專案作者保留一切權利。

---

