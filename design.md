# Landslide 会话循环管理工具 - 设计文档

## 1. 项目概述

本工具用于自动化管理 Spirent Landslide 测试平台的会话生命周期，按照指定的时间间隔循环执行"启动会话 → 运行指定时长 → 停止会话 → 清理资源"的完整流程。

## 2. 目录结构

```
/home/gsta/landsilde/
├── config.yaml              # Landslide 连接参数配置
├── config.json              # 流程时间间隔配置
├── design.md                # 本设计文档
├── README.md                # 使用说明
├── logs/                    # 日志输出目录
├── scripts/                 # Shell 脚本目录
│   ├── get_library_id.sh    # 查询 library_id
│   ├── sessionstart.sh      # 启动 Landslide 会话
│   ├── sessionstop.sh       # 停止 Landslide 会话
│   └── del_running_id.sh    # 删除 running_id 资源
└── worker/                  # Python 主进程目录
    └── main.py              # 主循环进程
```

## 3. 配置文件设计

### 3.1 config.yaml - Landslide 连接参数

```yaml
tas_ip: https://10.217.8.237:8181
user: sms
password: a1b2c3d4
library_name: sms/kiwi
case_name: DUPF167-1500pps-4w-TS1
```

| 字段 | 说明 | 示例值 |
|------|------|--------|
| tas_ip | Landslide TAS 服务器地址 | https://10.217.8.237:8181 |
| user | 认证用户名 | sms |
| password | 认证密码 | a1b2c3d4 |
| library_name | 测试库全名 | sms/kiwi |
| case_name | 测试用例名称 | DUPF167-1500pps-4w-TS1 |

### 3.2 config.json - 流程时间间隔配置

```json
{
    "landsilde_starttime": 300,
    "landsilde_stoptime": 60
}
```

| 字段 | 说明 | 单位 |
|------|------|------|
| landsilde_starttime | 启动会话后等待运行时长 | 秒(s) |
| landsilde_stoptime | 停止会话后等待时长 | 秒(s) |

## 4. RESTful API 接口说明

### 4.1 查询 library_id

- **URL**: `{tas_ip}/api/libraries`
- **方法**: GET
- **认证**: Basic Auth (user:password)
- **返回**: JSON 数组，匹配 `library_name` 获取 `id` 字段即为 `library_id`
- **示例响应**:
  ```json
  {
    "name": "sms/kiwi",
    "id": 65878,
    "testCasesUrl": "...",
    "testSessionsUrl": "..."
  }
  ```

### 4.2 启动 Landslide 会话

- **URL**: `{tas_ip}/api/runningTests`
- **方法**: POST
- **认证**: Basic Auth (user:password)
- **请求头**: Content-Type: application/json
- **请求体**: `{"library": <library_id>, "name": "<case_name>"}`
- **说明**: 启动成功后，会话进入 RUNNING 状态

### 4.3 查询 running_id

- **URL**: `{tas_ip}/api/runningTests`
- **方法**: GET
- **认证**: Basic Auth (user:password)
- **返回**: JSON 数组，筛选条件：
  - `library` 字段匹配 `library_id`
  - `name` 字段匹配 `case_name`
  - `testStateOrStep` 为 `"RUNNING"`
- **取值**: 匹配记录的 `id` 字段即为 `running_id`

### 4.4 停止 Landslide 会话

- **URL**: `{tas_ip}/api/runningTests/{running_id}?action=Stop`
- **方法**: POST
- **认证**: Basic Auth (user:password)
- **说明**: 发送停止指令，会话从 RUNNING 转为其他状态

### 4.5 删除 running_id 资源

- **URL**: `{tas_ip}/api/runningTests/{running_id}`
- **方法**: DELETE
- **认证**: Basic Auth (user:password)
- **说明**: 清理已停止的会话资源，释放服务器端占用

## 5. Shell 脚本设计

### 5.1 get_library_id.sh

**功能**: 调用 GET /api/libraries 接口，根据 config.yaml 中的 library_name 查找对应的 library_id，将结果写入 `/home/gsta/landsilde/library_id.txt` 供后续脚本使用。

**输入**: config.yaml 中的 tas_ip, user, password, library_name
**输出**: library_id 写入 library_id.txt，同时输出到 stdout

### 5.2 sessionstart.sh

**功能**: 读取 library_id.txt 中的 library_id，调用 POST /api/runningTests 接口启动会话，然后调用 GET /api/runningTests 获取 running_id，写入 `/home/gsta/landsilde/running_id.txt`。

**输入**: config.yaml 中的 tas_ip, user, password, case_name; library_id.txt 中的 library_id
**输出**: running_id 写入 running_id.txt，同时输出到 stdout

### 5.3 sessionstop.sh

**功能**: 读取 running_id.txt 中的 running_id，调用 POST /api/runningTests/{running_id}?action=Stop 接口停止会话。

**输入**: config.yaml 中的 tas_ip, user, password; running_id.txt 中的 running_id
**输出**: 停止结果输出到 stdout

### 5.4 del_running_id.sh

**功能**: 读取 running_id.txt 中的 running_id，调用 DELETE /api/runningTests/{running_id} 接口删除会话资源。

**输入**: config.yaml 中的 tas_ip, user, password; running_id.txt 中的 running_id
**输出**: 删除结果输出到 stdout

## 6. Python 主进程设计

### 6.1 主循环流程

```
┌─────────────────────────────────────────────────┐
│                    开始循环                       │
└──────────────────────┬──────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────┐
│ Step 1: 执行 get_library_id.sh                   │
│         等待 5 秒                                 │
└──────────────────────┬──────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────┐
│ Step 2: 执行 get_library_id.sh (二次确认)         │
│         等待 5 秒                                 │
└──────────────────────┬──────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────┐
│ Step 3: 执行 sessionstart.sh                     │
│         等待 landsilde_starttime 秒               │
└──────────────────────┬──────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────┐
│ Step 4: 执行 sessionstop.sh                      │
│         等待 landsilde_stoptime 秒                │
└──────────────────────┬──────────────────────────┘
                       ▼
┌──────────────────────────────────────────────────┐
│ Step 5: 执行 del_running_id.sh                   │
│         等待 10 秒                                │
└──────────────────────┬──────────────────────────┘
                       ▼
                  回到 Step 1
```

### 6.2 日志设计

- 日志同时输出到控制台和文件
- 日志文件路径: `/home/gsta/landsilde/logs/worker_{date}.log`
- 日志格式: `[%(asctime)s] [%(levelname)s] [%(module)s] %(message)s`
- 日志级别: INFO（生产），可调整为 DEBUG
- 关键日志点:
  - 每轮循环开始/结束
  - 每个步骤执行前后
  - 脚本执行的标准输出和错误输出
  - 等待时长的倒计时提示
  - 异常和错误信息

### 6.3 异常处理

- 脚本执行失败时记录错误日志，等待指定时间后继续下一轮循环
- 配置文件读取失败时记录错误并退出
- 网络请求超时或失败时记录错误，不中断主循环

### 6.4 数据文件

| 文件 | 路径 | 说明 |
|------|------|------|
| library_id.txt | /home/gsta/landsilde/library_id.txt | 存储查询到的 library_id |
| running_id.txt | /home/gsta/landsilde/running_id.txt | 存储当前会话的 running_id |

## 7. 依赖说明

- Python 3.6+
- PyYAML (读取 config.yaml)
- curl 命令行工具 (Shell 脚本调用 API)
- jq (Shell 脚本解析 JSON 响应，可选)
