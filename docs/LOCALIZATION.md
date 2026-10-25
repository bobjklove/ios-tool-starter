# 本地化流程

模板当前准备英语（`en`）、简体中文（`zh-Hans`）和日语（`ja`）。界面文案位于 String Catalog；商店元数据、隐私政策和购买说明需另行准备并审核。

截图脚本通过 `xcodebuild -testLanguage` 和 `-testRegion` 选择语言与地区。UI 测试不读取 `STORE_SCREENSHOT_LOCALE`；`-store-screenshot` 只启用 App 内的样例界面。脚本对每个设备与语言组合单独运行测试，并导出名为 `store-home` 的附件。

新增语言时：

1. 为 App 界面、商店元数据、隐私政策和购买说明分别补齐译文，并由熟悉该语言的人复核。
2. 更新 `tools/export-store-screenshots.py` 的语言/地区映射与输出矩阵；保留每个组合独立的 xcresult。
3. 通过对应的 `-testLanguage` 与 `-testRegion` 运行截图测试，检查附件来源、设备、实际显示语言、断行和小字。
4. 在最终文案构建后采集截图；完成语言和资源审核后重新运行敏感扫描。
