## 17 年会抽奖

## 实现逻辑

- 预告录入同事名单列表

### 同事端

- 录入自己名称，若匹配成功，随机分配一个数字
- 同事间数字相斥

仅知道自己被分配到的数字即可，尽量互动

### 抽奖端

- 转盘数字：同事分配的随机数字集合 + 随机因子
- 随机因子：不在被分配数字集合中的数字，数量 = 同事数量 / 2
- 获奖数字：从转盘数字中移除，若未命中同事，继续抽取
