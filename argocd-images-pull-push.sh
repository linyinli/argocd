#!/bin/bash
set -e
# 声明 ArgoCD 版本
version=v2.3.17
# 声明 ArgoCD 镜像列表
image_list=(
  quay.io/argoproj/argocd:${version}
  ghcr.io/dexidp/dex:v2.30.2
  quay.io/argoproj/argocd-applicationset:v0.4.1
  redis:6.2.6-alpine
  haproxy:2.4.9
  oliver006/redis_exporter:v1.27.0
)
# 声明 ArgoCD amd64 的镜像包名
amd64_images_tar="argocd-images-${version}-amd64.tar.gz"
# 声明镜像仓库地址为执行脚本时的第二个入参赋值
registry=$2

# 日志输出等级/颜色/时间的函数
info()
{
  echo '\033[36m[INFO]\033[0m' [`date "+%Y-%m-%d %H:%M:%S"`] "$@"
}
warn()
{
  echo '\033[33m[WARN]\033[0m' [`date "+%Y-%m-%d %H:%M:%S"`] "$@" >&2
}
fatal()
{
  echo '\033[31m[FATAL]\033[0m' [`date "+%Y-%m-%d %H:%M:%S"`] "$@" >&2
  exit 1
}

# 拉取 amd64 镜像的函数
pull_amd_image () {
  pulled=""
  for image in "${image_list[@]}"
    do
      # 拉取 amd64 镜像
      if docker pull "${image}" --platform=amd64 > /dev/null 2>&1 ; then
         # 拉取成功输出信息
         info "Image pull success: ${image}"
         # 重 tag 带上 -amd64 后缀
         docker tag "${image}" "${image}-amd64"
         # 拉取成功加入已拉取镜像列表，用于后面的 docker save 步骤
         pulled="${pulled} ${image}-amd64"
      else
         # 拉取失败输出信息并退出
         fatal "Image pull failed: ${image}, exit, please try to execute again."
      fi
   done
  # 提示正在打包 amd64 镜像
  info "Creating ${amd64_images_tar} with${pulled}"
  # 打包 amd64 镜像
  docker save $(echo ${pulled}) | gzip --stdout > ${amd64_images_tar}
}

# 推送镜像和 Manifest
push_manifest () {
  # 开启 Docker 实验性功能
  export DOCKER_CLI_EXPERIMENTAL=enabled
  # 加载 amd64 镜像包
  docker load --input ${amd64_images_tar}
  # 加载失败则退出  
  if [ $? -ne 0 ]; then
     fatal "Loading amd64 images failed, please try to execute again, or check the images tarball!"
  fi
  for image in "${image_list[@]}"
    do
      # 重 tag 镜像加上镜像仓库地址和项目
      docker tag "${image}-amd64" "$registry/argocd/${image}"
      docker tag "${image}-amd64" "$registry/argocd/${image}-amd64"
      # 推送 amd64 镜像到内网镜像仓库
      docker push "$registry/argocd/${image}"
      if [ $? -ne 0 ]; then
        # 推送失败则退出
        fatal "Image push failed: ${registry}/argocd/${image}, exit, please check and try to execute again."
      elses
        info "Image push success: ${registry}/argocd/${image}"
      fi
      # 推送 amd64 镜像到内网镜像仓库
      docker push "$registry/argocd/${image}-amd64"
      if [ $? -ne 0 ]; then
        # 推送失败则退出
        fatal "Image push failed: ${registry}/argocd/${image}-amd64, exit, please check and try to execute again."
      else
        info "Image push success: ${registry}/argocd/${image}-amd64"
      fi
   done
}
# 当脚本第一个入参为 pull 时，执行 pull_amd_image 函数
if [ "$1" = "pull" ]; then
  pull_amd_image
# 当脚本第一个入参为 push 时，执行 push_manifest 函数，${registry} 由第二个入参赋值，表明镜像仓库地址
elif [ "$1" = "push" ]; then
  push_manifest ${registry}
else
# 当脚本未提供入参或无法识别入参时，输出帮助信息
  warn "Usage: please use mode as ./argocd-images-pull-push.sh pull or ./argo-images-pull-push.sh push registry.example.com"
fi
