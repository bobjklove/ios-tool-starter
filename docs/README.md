# iOS 离线工具模板

本模板面向 iPhone 和 iPad，最低支持 iOS 17，包含 App、单元测试和 UI 测试三个 target。复制后按项目替换名称、类型名、bundle ID、文案、图标、支持与隐私网址。模板当前不启用签名。

## 快速开始

1. 更新 `project.yml` 中的 App、测试 target、bundle ID、资源路径和本地化设置。
2. 将 `ToolStarter.xctestplan` 与其在 `project.yml` 中的引用一起改名；核对测试计划里的 `storeKitConfiguration` 路径。生成工程时，`tools/sync-test-plan.py` 的 postGen 步骤会同步生成工程中的 target 标识和容器引用。
3. 修改 `tools/icon/DrawIcon.swift` 后，重新生成 App 图标：`swift tools/generate-app-icon.swift tools/icon/DrawIcon.swift App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`。
4. 运行 `xcodegen generate`。
5. 在仓库外确认工作区目录后，使用 slot 串行执行模拟器构建与测试。`.build/` 集中存放派生数据、xcresult、日志和截图。

默认 `ToolStarter` scheme 使用 `ToolStarter.xctestplan`，实际运行单元与本地 StoreKit 测试；UI 测试 target 会编译，但该计划不执行 UI 测试。可用以下命令实跑默认计划：

```sh
bash ~/.claude/bin/slot.sh run build 1 -- xcodebuild test \
  -project ToolStarter.xcodeproj \
  -scheme ToolStarter \
  -derivedDataPath .build/dd \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'
```

商店截图通过 `ToolStarterScreenshots` scheme 单独运行，见下方脚本。真机验收、签名、后台商品配置和提交审核需按项目流程分别完成；本模板文档不代表这些步骤已通过。

## 四个工具

图标脚本接收定义 `drawIcon(context:size:)` 的 Swift 文件，输出并验证 1024×1024、无透明通道的 RGB PNG：

```sh
swift tools/generate-app-icon.swift DrawIcon.swift .build/AppIcon.png
```

商店截图脚本串行采集 6.9 英寸 iPhone、13 英寸 iPad，以及英语、简体中文、日语组合；需要已存在的模拟器，不安装运行时。每轮都经 slot 执行，结束时关闭模拟器。截图放在 `.build/store-screenshots/`：

```sh
python3 tools/export-store-screenshots.py --scheme ToolStarterScreenshots
```

脚本也接受 `--project`、`--scheme`、`--output`。语言由 `xcodebuild -testLanguage` 与 `-testRegion` 设置；UI 测试中的 `-store-screenshot` 只是启用样例画面的标记。测试附件名为 `store-home`。

PDF 脚本用 PDFKit 检查 A4 或 Letter 页面尺寸，并对渲染后的非白色内容边界与 JSON 几何清单进行比对。清单矩形单位为毫米，原点在页面左下角：

```json
{"pages":[{"page":1,"paper":"A4","imageRectMillimeters":[13,22,75,105],"toleranceMillimeters":0.25}]}
```

```sh
swift tools/verify-pdf.swift output.pdf .build/pdf-geometry.json
```

边界验证样例应在白底上绘制单个纯色矩形，并让源图延伸到目标裁切框以外，从 PDF 渲染结果确认实际裁切边界。带透明或白色留边的图片需单独构造边界夹具。

敏感扫描覆盖文本源码、文档和资源中的可读文本，跳过 `.build`、`.xcodeproj`、`.xcworkspace` 等生成物；追加客户名或产品词可重复使用 `--deny`：

```sh
python3 tools/scan-sensitive.py . --deny '客户或产品词'
```

核对流程和边界见 [购买与 StoreKit](PURCHASES.md)、[隐私申报](PRIVACY.md)、[上架清单](RELEASE_CHECKLIST.md) 与 [本地化](LOCALIZATION.md)。
