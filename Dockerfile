FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/python:3.10-slim

LABEL maintainer="landslide-worker"
LABEL description="Landslide Session Loop Manager"

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list 2>/dev/null || true

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

#RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple PyYAML
RUN pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple/ PyYAML==6.0.1

WORKDIR /app

COPY config.yaml /app/config.yaml
COPY config.json /app/config.json
COPY scripts/ /app/scripts/
COPY worker/ /app/worker/

RUN chmod +x /app/scripts/*.sh

RUN mkdir -p /app/logs

VOLUME ["/app/logs"]

ENV PYTHONUNBUFFERED=1

CMD ["python3", "/app/worker/main.py"]
