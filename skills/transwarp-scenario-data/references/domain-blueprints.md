# 领域蓝图

先构造最小可复现场景，不要一开始就追求覆盖所有主题域。

## 银行

常见最小实体集：

- `customer`
- `account`
- `card`
- `txn`
- `org_unit`
- `product`
- `customer_tag`

优先保住：

- 客户到账户的一对多
- 账户到卡的一对多或一对一
- 交易晚于开户时间
- 金额与状态值合法

## 证券

常见最小实体集：

- `investor`
- `fund_account`
- `securities_account`
- `trade_order`
- `trade_match`
- `position`
- `broker_branch`

优先保住：

- 投资者与资金账户、证券账户关系
- 委托、成交、持仓链路
- 交易日和清算日逻辑

## 政务

常见最小实体集：

- `person`
- `organization`
- `case_event`
- `region_dim`
- `service_record`
- `tag`

优先保住：

- 人、机构、地区的层级关系
- 事件时间线
- 状态流转

## 银联或清算类离线场景

常见最小实体集：

- `customer`
- `account`
- `card`
- `merchant`
- `terminal`
- `txn`
- `clear_txn`
- `recon_result`
- `org_unit`

优先保住：

- 交易、清算、对账链路
- 机构与渠道分布
- 交易时间峰值和热点机构
- 汇总层可由事实层回算
