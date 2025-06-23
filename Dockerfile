# 第一阶段：构建前端
FROM node:18-alpine AS frontend-builder

WORKDIR /app

# 复制前端代码
COPY glc/www/web /app

# 安装Python和构建工具，这些是node-sass所需的
#RUN apk add --no-cache python3 make g++

# 全局安装pnpm
RUN npm install -g pnpm

# 使用pnpm安装依赖并构建前端
RUN pnpm config set registry https://repo.huaweicloud.com/repository/npm/ && \
    pnpm install --no-frozen-lockfile && \
    pnpm run build

# 第二阶段：构建Go应用
FROM golang:1.23-alpine AS backend-builder

WORKDIR /app

# 复制Go代码
COPY glc /app

# 设置Go代理以加速依赖下载
RUN go env -w GO111MODULE=on && \
    go env -w GOPROXY=https://goproxy.cn,direct

# 复制前端构建产物到正确位置
COPY --from=frontend-builder /app/dist /app/www/web/dist

# 构建Go应用
RUN go build -ldflags "-w -s" -o glc

# 第三阶段：最终运行镜像
FROM alpine:3.18 AS runner

# 复制Go二进制文件
COPY --from=backend-builder /app/glc /usr/local/bin/

# 复制前端构建产物
COPY --from=frontend-builder /app/dist /usr/local/bin/www/web/dist

# 设置时区和基础工具
RUN alpine_version=$(cat /etc/issue | head -1 | awk '{print $5}') \
    && echo "https://mirrors.aliyun.com/alpine/v${alpine_version}/main/" > /etc/apk/repositories \
    && apk update && apk upgrade && apk add --no-cache bash bash-doc bash-completion tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone \
    && rm -rf /var/cache/apk/*

# 暴露端口
EXPOSE 8080

# 设置启动命令
ENTRYPOINT ["glc", "--docker"]
