# Landslide 会话循环管理工具

自动化管理 Spirent Landslide 测试平台的会话生命周期，按照指定时间间隔循环执行启动/停止/清理操作。

## 目录结构

```
/home/gsta/landsilde/
├── config.yaml              # Landslide 连接参数配置
├── config.json              # 流程时间间隔配置
├── design.md                # 设计文档
├── README.md                # 本文件
├── library_id.txt           # 运行时生成的 library_id 缓存
├── running_id.txt           # 运行时生成的 running_id 缓存
├── logs/                    # 日志输出目录
│   └── worker_YYYYMMDD.log
├── scripts/                 # Shell 脚本目录
│   ├── get_library_id.sh    # 查询 library_id
│   ├── sessionstart.sh      # 启动 Landslide 会话
│   ├── sessionstop.sh       # 停止 Landslide 会话
│   └── del_running_id.sh    # 删除 running_id 资源
└── worker/                  # Python 主进程目录
    └── main.py              # 主循环进程
```

## 配置说明

### config.yaml - Landslide 连接参数

| 字段 | 说明 | 示例 |
|------|------|------|
| tas_ip | Landslide TAS 服务器地址 | https://10.217.8.237:8181 |
| user | 认证用户名 | sms |
| password | 认证密码 | a1b2c3d4 |
| library_name | 测试库全名 | sms/kiwi |
| case_name | 测试用例名称 | DUPF167-1500pps-4w-TS1 |

### config.json - 流程时间间隔

| 字段 | 说明 | 单位 |
|------|------|------|
| landsilde_starttime | 启动会话后等待运行时长 | 秒(s) |
| landsilde_stoptime | 停止会话后等待时长 | 秒(s) |

## 执行流程

每轮循环依次执行以下 5 个步骤：

| 步骤 | 脚本 | 说明 | 等待时长 |
|------|------|------|----------|
| 1 | get_library_id.sh | 查询 library_id（第1次） | 5s |
| 2 | get_library_id.sh | 查询 library_id（第2次确认） | 5s |
| 3 | sessionstart.sh | 启动 Landslide 会话 | landsilde_starttime |
| 4 | sessionstop.sh | 停止 Landslide 会话 | landsilde_stoptime |
| 5 | del_running_id.sh | 删除 running_id 资源 | 10s |

步骤 5 完成后回到步骤 1，无限循环。

## 快速开始

### 方式一：Docker 运行（推荐）

#### 前置条件

- Docker
- Docker Compose（可选）

#### 构建镜像

```bash
cd /home/gsta/landsilde
docker build -t landslide-worker:latest .
```

#### 使用 Docker Compose 运行

```bash
docker-compose up -d
```

#### 使用 Docker 命令运行

```bash
docker run -d \
  --name landslide-worker \
  --restart always \
  -v $(pwd)/config.yaml:/app/config.yaml:ro \
  -v $(pwd)/config.json:/app/config.json:ro \
  -v $(pwd)/logs:/app/logs \
  landslide-worker:latest
```

#### 查看日志

```bash
docker logs -f landslide-worker
```

#### 停止容器

```bash
docker-compose down
# 或
docker stop landslide-worker && docker rm landslide-worker
```

#### 更新配置后重启

修改 `config.yaml` 或 `config.json` 后：

```bash
docker-compose restart
# 或
docker restart landslide-worker
```

### 方式二：直接运行

#### 前置条件

- Python 3.6+
- PyYAML 库
- curl 命令行工具
- jq (JSON 解析工具)

#### 启动

```bash
cd /home/gsta/landsilde
python3 worker/main.py
```

#### 后台运行

```bash
nohup python3 /home/gsta/landsilde/worker/main.py > /dev/null 2>&1 &
```

#### 停止

使用 Ctrl+C 或 kill 进程即可，程序会优雅退出。

## 日志

- 日志文件位于 `logs/worker_YYYYMMDD.log`
- 同时输出到控制台
- 日志格式: `[时间] [级别] [模块] 消息`
- 包含每个步骤的执行结果、脚本输出、等待倒计时等详细信息

## 脚本说明

### get_library_id.sh

调用 `GET /api/libraries` 接口，根据 config.yaml 中的 library_name 查找对应的 library_id，结果写入 `library_id.txt`。

### sessionstart.sh

读取 library_id.txt，调用 `POST /api/runningTests` 启动会话，然后查询 `GET /api/runningTests` 获取状态为 RUNNING 的 running_id，写入 `running_id.txt`。

### sessionstop.sh

读取 running_id.txt，调用 `POST /api/runningTests/{running_id}?action=Stop` 停止会话。

### del_running_id.sh

读取 running_id.txt，调用 `DELETE /api/runningTests/{running_id}` 删除会话资源，并清理 running_id.txt 文件。

## 注意事项

- 所有 API 请求使用 `-k` 参数跳过 SSL 证书验证
- 脚本执行超时时间为 120 秒
- 单个步骤失败不会中断整个循环，会继续执行后续步骤
- 修改 config.yaml 或 config.json 后，下一轮循环自动生效
# landsilde
