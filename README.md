# NBA 卡包商城

2025 年網路程式設計期末專案，以 Java/JSP 搭配 MySQL，提供球員卡、卡盒與周邊商品商城。

包含商品瀏覽、搜尋、會員、購物車、結帳、留言、商品評價及管理後台。

## 系統畫面

### 商城首頁

![NBA 卡包商城首頁，顯示商品分類導覽與商城主視覺](docs/screenshots/home.png)

### 商品瀏覽

| NBA 球員卡 | NBA 卡盒專區 |
| --- | --- |
| ![球員卡列表，含篩選選單與商品卡片](docs/screenshots/cards.png) | ![卡盒專區，顯示球員主題卡盒與商品標籤](docs/screenshots/card-boxes.png) |
| **卡片周邊商品** | **特別商品** |
| ![卡片周邊商品列表，顯示展示架、收藏盒與保護配件](docs/screenshots/accessories.png) | ![特別商品列表，顯示紀念卡與限量商品](docs/screenshots/special.png) |

### 商品詳情與購物車

| 商品詳情 | 購物車 |
| --- | --- |
| ![商品詳情，顯示姚明球員卡、價格與商品資訊](docs/screenshots/product-detail.png) | ![購物車頁面的未登入狀態，畫面提供登入入口](docs/screenshots/cart.png) |

### 會員與評論

| 會員登入 | 商品評論留言板 |
| --- | --- |
| ![會員登入畫面，含登入表單與註冊入口](docs/screenshots/login.png) | ![商品評論留言板，顯示評論統計與最新評論區](docs/screenshots/message-board.png) |

### 服務與商城資訊

| 服務中心 | 關於我們 |
| --- | --- |
| ![服務中心，含購物指南、配送資訊、退換貨與會員服務](docs/screenshots/help.png) | ![關於我們頁面，介紹商城的品牌故事與使命](docs/screenshots/about.png) |

## 原始碼

- [商城首頁](src/main/webapp/index.jsp)
- [網頁、JSP 後端、CSS 與圖片](src/main/webapp/)
- [管理後台](src/main/webapp/admin/)
- [資料庫結構與展示商品資料](src/main/sql/nba_database_final.sql)

## 執行設定

需要 Java、支援 JSP 的伺服器（例如 Apache Tomcat）、MySQL 和 MySQL Connector/J。資料庫匯出自 MySQL 8.4.0，原使用的 Java、Tomcat 與 JDBC 驅動版本尚未確認。此備份未包含伺服器、JDBC JAR 或建置設定。

1. 在專用的本機 MySQL 測試環境匯入 SQL。它會建立 `nba_db`，且包含 `DROP TABLE IF EXISTS`，不要對現有重要資料庫直接執行。
2. 在啟動 Tomcat 的環境設定下列變數：

   | 變數 | 用途 |
   | --- | --- |
   | `NBA_DB_URL` | JDBC 網址，例如 `jdbc:mysql://localhost:3306/nba_db?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Taipei` |
   | `NBA_DB_USER` | 本機 MySQL 使用者 |
   | `NBA_DB_PASSWORD` | 本機 MySQL 密碼 |

3. 將 `src/main/webapp/` 的內容部署到 Tomcat 應用程式目錄，透過應用程式網址開啟 `index.jsp`。

資料庫初始化、批次更新及清理由維護人員透過資料庫工具操作。
4. 歷史會員資料未附入，可由網站註冊測試會員。

## 資安防護

- **註冊與修改密碼**使用加鹽 PBKDF2-HMAC-SHA256（600,000 次迭代）。既有明文密碼在成功登入後轉成雜湊，更新時會核對舊值，避免覆寫其他請求剛修改的密碼。
- **登入成功後**重發 Session ID，Session Cookie 使用 `HttpOnly`，登入後只允許轉往指定商城頁面。
- **訂單清單及詳情**只開放管理員。封鎖會匯入、清理及批次更新資料的維護頁。公開狀態頁只回報整體可用性。

已在隔離的 Tomcat 與 MySQL 驗證註冊、修改密碼、舊密碼升級和 Session ID 更新。匿名與一般會員會被訂單管理頁拒絕，管理員可讀取訂單清單。既有部署中仍以明文儲存的帳號應重設密碼，正式環境的結帳與完整後台操作仍需驗收。見 [密碼處理](src/main/webapp/WEB-INF/member_password.jspf)、[管理員檢查](src/main/webapp/WEB-INF/require_admin.jspf)、[Servlet 設定](src/main/webapp/WEB-INF/web.xml)。

## 備份範圍

- 保留找到的全部 139 個來源檔案，未重複放入 ZIP 備份、較早的純前端版本或無關課堂練習。
- 原本寫死的 MySQL 連線設定改由環境變數讀取，未上傳原密碼。
- 保留全部資料表結構與商品等展示資料，移除歷史會員、購物車、訂單、積分、留言、評論及相關紀錄，另移除歷史站台設定與統計資料。
- 原始本機檔案未被覆寫。

這是課程專案的原始碼備份，已在本機驗證商品頁、會員註冊與登入，以及商品評論流程。會員密碼處理、管理員權限與資料庫診斷及維護頁面沿用舊實作；正式對外部署前需另行檢查。
