# 切片 4：统计升级 — 待做清单

> 参考架构设计.md 4.4~4.6 节。按优先级排列。

---

## P0 — 投资总览（投资页面头部）

投资页面顶部加总览 Card：持仓收益 + 累计收益。

1. DatabaseHelper 新增 getInvestmentSummary(bookId)
2. investment_page.dart 列表顶部加总览 Card

详见架构设计.md 4.4 节。

---

## P1 — 图表升级

| 图表 | 状态 |
|------|------|
| 柱状图 BarChart（近6月支出对比） | 待实现 |
| 折线图 LineChart（净资产趋势） | 待实现 |
| 饼图 PieChart（月度分类占比） | 已实现 |

---

## P2 — 多维筛选

- 时间维度扩展（日/周/季/年/自定义）
- 统计页接账户维度筛选（流水页已实现）

---

## 已知遗留

1. NAV 回滚测试已移除（原因待查），核心代码已部署
2. 卖出费率手动输入，不做自动 FIFO
3. B基金成本 = fromAmount - refund（已实现）

---

## 项目状态

dart analyze    -> 0 error, 0 warning
flutter test    -> 28/28 All tests passed
最新提交       -> 3a8fde1
设计文档       -> 架构设计.md / 开发路线图.md（仓库内）
