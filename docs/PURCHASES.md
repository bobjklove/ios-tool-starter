# 购买与 StoreKit

## 当前模板配置

- 永久解锁商品 ID：`com.example.toolstarter.unlock`，商品类型为非消耗型。价格和销售地区由项目负责人在商店后台决定并核对。
- 免费额度为 3 次成功导出；本地成功导出历史使用 `UserDefaults` 键 `free-export-history-v1`。重复导出相同内容不会重复扣额度；失败或取消的分享不记为成功。
- 恢复购买入口在买断页，不在设置页。点击后调用 `AppStore.sync()`。
- 首次上架时，永久解锁商品须与 App 首版一并提交审核；商店商品是否已创建、价格是否正确，需由负责人另行核实。

## 已有测试与未覆盖事项

`StoreKitIntegrationTests.testOfflinePurchaseAndRevocation` 使用本地 StoreKit 配置验证商品读取、购买解锁以及退款撤销后重新锁定。`PurchaseStateTests` 对 pending、取消、失败和未验证事件进行纯状态机断言，确认这些状态本身不会解锁；这些不是 StoreKit 系统集成场景。

恢复流程的 `AppStore.sync()` 尚无集成测试或真机验收。当前也没有完成沙盒账号购买流程的真机验收。不得把本地状态机测试描述成系统购买、pending、取消或恢复流程已验收。

本地 StoreKit 配置只用于开发和测试，不证明后台商品配置或 App Store 审核状态。价格、本地化、税务展示、销售地区和首版送审安排由项目负责人在后台核实。
