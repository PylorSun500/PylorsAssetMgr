# PylorsAssetMgr — 数字资产管理器需求规格

> 版本: 1.0 | 日期: 2026-05-25 | 当前实现: Python tkinter 原型 | 目标: Swift 原生 macOS 应用

---

## 一、产品概述

PylorsAssetMgr 是一个面向创意工作者的**本地数字资产管理器**。它不替代 Finder，而是在文件系统之上叠加一层**以标签为核心的浏览与管理视图**，让用户能够按自己的语义体系组织、筛选、查找文件。

### 核心设计哲学

> **「一切皆标签」**

文件名 `概念设计-v3`、格式 `.psd`、大小 `2.3 MB`、重要性 `high`、客户 `Acme`——这些在本体论上是平等的，区别仅在于前几个是系统自动提取的，后几个是用户赋予的。不存在"固定列"，所有属性统一为 `key:value` 标签对。

这一设计直接继承了 Unix 「一切皆文件」的哲学，将其映射到资产管理领域。

---

## 二、概念模型

### 2.1 工作区（Workspace）

- 一个工作区 = 一个**真实文件系统目录**
- 工作区根目录下存放 `.pylorsmeta.db`（SQLite），类似 `.DS_Store`
- 多个工作区以**浏览器标签页**形式并存于同一窗口
- 工作区之间完全独立，互不干扰

### 2.2 资产（Asset）

- 资产 = 工作区内的一个文件或目录
- 每个资产由两部分信息构成：
  - **系统标签**：从文件系统实时读取，不持久化存储
  - **用户标签**：用户自定义的 `key:value` 对，持久化在 SQLite

### 2.3 标签（Tag）

- 标签统一为 `key:value` 字符串对
- **系统标签键**（固定集合，不可编辑）：
  - `name` — 文件名（含扩展名）
  - `stem` — 文件名（不含扩展名）
  - `suffix` — 扩展名（如 `.jpg`）
  - `size` — 字节数
  - `size_display` — 人类可读大小
  - `ctime` / `mtime` — 创建/修改时间戳
  - `ctime_display` / `mtime_display` — 格式化时间
  - `width` / `height` / `dimensions` — 图片尺寸
  - `is_dir` — 目录/文件类型

- **用户标签键**（用户自定义，无限制）：
  - 键名规则：`[a-zA-Z一-鿿][a-zA-Z0-9一-鿿_-]*`
  - 值：任意字符串
  - 内置建议键：`importance`（优先级）、`status`（状态）、`client`（客户）、`note`（备注）
  - 用户可随时创建新键，无需修改数据库 schema

- **重要性标签**（约定俗成，非系统特殊处理）：
  - `importance:high` / `importance:medium` / `importance:low`
  - 右键菜单提供快捷设置选项

---

## 三、数据模型

### 3.1 存储位置

每个工作区根目录下一个 SQLite 文件：
```
/path/to/workspace/.pylorsmeta.db
```

### 3.2 数据库 Schema（EAV 模型）

```sql
-- 用户标签：EAV 模型，键值对
CREATE TABLE user_tags (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path  TEXT NOT NULL,    -- 相对工作区根目录的路径
    key        TEXT NOT NULL,    -- 标签键
    value      TEXT NOT NULL,    -- 标签值
    updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    UNIQUE(file_path, key)
);

CREATE INDEX idx_user_tags_path ON user_tags(file_path);
CREATE INDEX idx_user_tags_key  ON user_tags(key);
CREATE INDEX idx_user_tags_kv   ON user_tags(key, value);

-- 工作区配置：键值存储
CREATE TABLE workspace_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- 配置项：
--   visible_columns: 逗号分隔的可见列键名列表
--   column_widths:   JSON {"key": width_px, ...}
--   sidebar_visible: "1" / "0"

-- 标签键注册表：记录所有已使用过的用户标签键
CREATE TABLE tag_key_registry (
    key        TEXT PRIMARY KEY,
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TRIGGER tr_register_tag_key
AFTER INSERT ON user_tags
BEGIN
    INSERT OR IGNORE INTO tag_key_registry (key) VALUES (NEW.key);
END;
```

### 3.3 设计决策

| 决策 | 原因 |
|------|------|
| EAV 模型而非 JSON 列 | 支持按 key/value 建索引做搜索，`get_bulk_tags` 一次查询取回所有文件的所有标签 |
| 系统标签不存 DB | 文件随时被外部修改，`os.stat` 性能足够（10000 文件 ≈ 1 秒），保证数据一致性 |
| 单值标签 | 每个文件每个键只有一个值，多值需求用逗号分隔值或命名约定处理 |
| 路径标识（非 inode） | v1 简单优先，后续可选 inode + hash 匹配做文件重命名恢复 |
| WAL 模式 | 支持多窗口读，写入串行化 |

---

## 四、核心数据流

```
用户操作：打开工作区 / 切换子目录 / 刷新 / 搜索
    │
    ├── 1. 扫描文件系统 ─────────────────────────────────
    │    递归遍历目录，对每个文件调用 stat() 提取系统标签
    │    跳过：.DS_Store, .pylorsmeta.db, Thumbs.db, 隐藏文件
    │    最大深度：50 层
    │
    ├── 2. 批量查询用户标签 ──────────────────────────────
    │    SELECT file_path, key, value FROM user_tags
    │    WHERE file_path IN (?, ?, ...)
    │    一次查询取回所有文件的用户标签
    │
    ├── 3. 合并 ─────────────────────────────────────────
    │    系统标签 dict + 用户标签 dict → Asset 对象
    │
    ├── 4. 清理过期标签 ─────────────────────────────────
    │    删除 DB 中引用不存在文件的标签记录
    │
    ├── 5. 排序 ─────────────────────────────────────────
    │    按当前排序键排序，排序键不存在时排到末尾
    │    数字字段按数值排序（size），其余按字符串
    │
    ├── 6. 过滤 ─────────────────────────────────────────
    │    解析 key:value 过滤字符串，AND 逻辑匹配
    │    支持 * 通配符
    │
    └── 7. 渲染到视图 ───────────────────────────────────
        仅显示可见列，显示过滤后的行
```

---

## 五、界面设计

### 5.1 窗口布局

```
┌──────────────────────────────────────────────────────┐
│ 菜单栏：文件 | 视图                                    │
├──────────────────────────────────────────────────────┤
│ [项目A ×] [素材库 ×] [交付物 ×] [+]     ← 标签栏      │
├──────────────────────────────────────────────────────┤
│ 筛选: [importance:high         ] [应用] [清除]        │
├────────┬─────────────────────────────────────────────┤
│ 目录树 │  文件名    │ 格式 │ 大小  │ 修改时间         │
│ ├─设计  │  logo-v3  │ .psd │ 12 MB │ 2026-05-20     │
│ ├─导出  │  mockup   │ .png │ 2.3MB │ 2026-05-18 ▲  │
│ └─文档  │  brief    │ .pdf │ 450KB │ 2026-05-15     │
│         │  ...      │ ...  │ ...   │ ...            │
├────────┴─────────────────────────────────────────────┤
│ 34 个资产（共 45 个） │ 筛选: importance:high         │
└──────────────────────────────────────────────────────┘
```

### 5.2 组件清单

| 组件 | 功能 |
|------|------|
| **Menu Bar** | 文件（打开/关闭工作区/刷新/退出）、视图（选择可见列/切换侧边栏） |
| **Tab Bar** | 工作区标签页，支持添加[+]/关闭[×]/切换/拖拽排序，显示文件夹名 |
| **Filter Bar** | `key:value` 搜索，多条件空格分隔 AND 逻辑，支持 `*` 通配符，自由文本模糊搜索 |
| **Dir Tree** | 左侧可选目录树，单击过滤到该子目录，支持展开/折叠/懒加载 |
| **Asset Table** | 核心详情列表视图，可排序列，多选，右键菜单，双击编辑 |
| **Status Bar** | 显示资产数量、筛选条件、工作区路径 |

### 5.3 交互规格

| 操作 | 行为 |
|------|------|
| **单击列头** | 按该列排序（再点击切换升/降序），显示 ▲▼ 指示器 |
| **右键列头** | 弹出列选择器，勾选哪些标签键作为可见列 |
| **双击用户标签单元格** | 弹出编辑框，提供历史值 Combobox 建议 |
| **双击系统标签单元格** | 提示"系统标签不可编辑" |
| **右键资产行** | 上下文菜单：打开文件/复制路径/批量编辑/快捷打标 |
| **Ctrl/Shift+点击** | 多选资产行 |
| **Cmd+O** | 打开工作区 |
| **Cmd+W** | 关闭当前工作区 |
| **Cmd+R** | 刷新当前视图 |
| **Cmd+B** | 切换侧边栏显示 |
| **Cmd+Q** | 退出应用 |
| **拖拽列头边框** | 调整列宽，自动持久化 |
| **点击目录树节点** | 过滤显示该子目录内的资产 |
| **输入 `importance:high`** | 筛选所有 importance 为 high 的资产 |
| **输入 `report`** | 在所有标签值中模糊搜索 "report" |

### 5.4 对话框

| 对话框 | 场景 | 内容 |
|--------|------|------|
| **标签编辑** | 双击单元格 | 资产名 + 标签键 + 值输入（Combobox 历史建议） |
| **批量标签编辑** | 多选后右键 | 资产数量 + 标签键 + 标签值 |
| **列选择器** | 右键表头 / 视图菜单 | 系统列 + 用户列 分类，Checkbutton 勾选，支持新建键 |

---

## 六、缩略图方案

### 当前 Python 实现

调用 macOS 内置 `qlmanage -t`（Quick Look Thumbnail）：
```bash
qlmanage -t -s 128 -o /cache/dir /path/to/file
```
- 缓存目录：`<workspace>/.pylorsthumb/`
- 优势：零依赖，支持几乎所有文件格式（PDF/PSD/AI/视频）
- 劣势：每次调用 subprocess，性能一般

### Swift 迁移方案

直接使用 `QLThumbnailGenerator` API：
- `QLThumbnailGenerator.shared.generateBestRepresentation(for: ...)`
- 异步生成，系统级缓存，内存管理由 OS 处理
- 效果远优于 qlmanage subprocess 方案

---

## 七、边界情况处理

| 边界 | 策略 |
|------|------|
| 文件被外部删除 | 每次刷新后调用 `cleanup_stale_tags()` 清理 DB 孤儿记录 |
| 文件被外部重命名 | 旧路径标签成为孤儿后被清除；后续可选 hash+inode 匹配恢复 |
| 超大目录（10 万+文件） | 生成器模式扫描 + 列表虚拟滚动 |
| Unicode 文件名 | 原生 Path 支持，SQLite TEXT UTF-8 |
| 符号链接 | 默认跳过循环链接 |
| 标签键非法字符 | 写入前校验，不合规拒绝写入 |
| DB 文件损坏 | 启动时 `PRAGMA integrity_check`，损坏则备份旧文件并重建 |
| 缩略图生成失败 | 静默失败，不阻断主流程，显示默认占位 |
| 编辑即保存 | 每次 set_tag 直接写入 DB，无"未保存更改"问题 |
| 窗口关闭 | 保存当前列宽配置，关闭所有 DB 连接 |

---

## 八、技术实现

### 8.1 当前原型（Python + tkinter）

| 维度 | 选型 |
|------|------|
| 语言 | Python 3.14 |
| GUI | tkinter + ttk |
| 数据库 | SQLite3（标准库） |
| 图片尺寸 | Pillow |
| 缩略图 | `qlmanage -t` subprocess |
| 依赖 | Pillow（仅此一个外部依赖） |
| 文件数 | 28 个 Python 文件 |

### 8.2 目标实现（Swift 原生 macOS 应用）

| 维度 | 选型 |
|------|------|
| 语言 | Swift 6 |
| UI 框架 | SwiftUI（首选）或 AppKit |
| 数据持久化 | SQLite（GRDB.swift 或直接 SQLite.swift） |
| 缩略图 | `QLThumbnailGenerator`（QuickLookUI） |
| 文件监听 | `FSEvents` / `NSFilePresenter` |
| 图片元数据 | `CGImageSource` / `NSImage` |
| 最低部署 | macOS 15 Sequoia |

### 8.3 Swift 架构映射

```
PylorsAssetMgr/
├── PylorsAssetMgrApp.swift          # @main App 入口
├── Models/
│   ├── Asset.swift                   # Asset 结构体（Identifiable）
│   ├── TagStore.swift                # SQLite EAV CRUD
│   ├── Workspace.swift               # 工作区模型
│   └── FilterEngine.swift            # 过滤解析与匹配
├── ViewModels/
│   ├── WorkspaceViewModel.swift      # 工作区状态管理（@Observable）
│   └── AssetListViewModel.swift      # 资产列表数据
├── Views/
│   ├── MainWindow.swift              # 主窗口布局
│   ├── TabBar.swift                  # 标签栏
│   ├── AssetListView.swift           # 详情列表（Table/NSOutlineView 替代品）
│   ├── FilterBarView.swift           # 过滤栏
│   ├── DirTreeView.swift             # 目录树（NSOutlineView）
│   ├── StatusBarView.swift           # 状态栏
│   ├── ColumnPickerPopover.swift     # 列选择器
│   ├── TagEditorPopover.swift        # 标签编辑
│   └── BatchEditSheet.swift          # 批量编辑
├── Services/
│   ├── FileScanner.swift             # 文件系统扫描
│   ├── ThumbnailService.swift        # QLThumbnailGenerator 封装
│   └── FileMonitorService.swift      # FSEvents 文件变更监听
└── Resources/
    └── Assets.xcassets               # 应用图标
```

### 8.4 Swift 相比 Python 原型的优势

| 方面 | Python tkinter | Swift 原生 |
|------|---------------|-----------|
| 列表性能 | Treeview 1000 行开始卡 | NSTableView 虚拟滚动，10 万行流畅 |
| 缩略图 | subprocess qlmanage | `QLThumbnailGenerator` 异步系统 API |
| 文件监听 | 需手动轮询 | `FSEvents` 内核级推送，文件变更即时刷新 |
| 暗色模式 | 手动检测，部分生效 | 自动跟随，所有原生控件完美适配 |
| 右键菜单 | tkinter Menu | `NSMenu` + `NSMenuItem` 原生右键菜单 |
| 列头拖拽排序 | 不支持 | `NSTableView` 原生支持 |
| 应用分发 | 需 Python 环境 | 单一 .app bundle，直接拖进 /Applications |
| 沙盒 / 权限 | 无 | 原生 entitlements |
| SF Symbols | 无 | 5000+ 系统图标 |
| 无障碍 | 基本无 | 原生 VoiceOver 支持 |
| 内存管理 | GC | ARC 编译期引用计数 |

---

## 九、已知限制与未来规划

### 当前原型限制
- tkinter Treeview 不支持缩略图嵌入（需自绘 Canvas 或用侧边预览面板）
- 大目录（10000+ 文件）列表性能有限
- 无文件系统事件监听，需手动刷新
- UI 风格受限于 tkinter 控件

### Swift 版本规划
- [ ] 实时文件变更监听（FSEvents），列表自动更新
- [ ] 缩略图列（Quick Look 异步生成 + 缓存）
- [ ] 列拖拽排序（NSTableView 原生）
- [ ] 预览面板（选中文件显示大缩略图 + 完整标签）
- [ ] 拖拽文件到窗口批量导入标签
- [ ] Spotlight 集成（标签写入 Spotlight 元数据，系统搜索可找到）
- [ ] 标签模板（预设标签组，一键应用）
- [ ] 导出/导入 sidecar JSON（git 友好）
- [ ] iCloud 同步（通过 CloudKit）

---

## 十、开发环境要求

### 当前原型
```bash
# macOS 15 + Homebrew
brew install python@3.14 python-tk@3.14
pip install Pillow
python3 run.py
```

### Swift 目标
- macOS 15 Sequoia
- Xcode 17+
- Swift 6

---

*本文档即后续 Swift 重写的完整需求规格。*
