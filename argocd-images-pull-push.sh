#!/bin/bash
set -e
version=v2.5.10
image_list=(
  quay.io/argoproj/argocd:${version}
  ghcr.io/dexidp/dex:v2.35.3
  redis:7.0.7-alpine
  haproxy:2.6.4
  public.ecr.aws/bitnami/redis-exporter:1.45.0
)
amd64_images_tar="argocd-images-${version}-amd64.tar.gz"
arm64_images_tar="argocd-images-${version}-arm64.tar.gz"
registry=$2

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

pull_amd_image () {
  pulled=""
  for image in "${image_list[@]}"
    do
      if docker pull "${image}" --platform=amd64 > /dev/null 2>&1 ; then
         info "Image pull success: ${image}"
         docker tag "${image}" "${image}-amd64"
         pulled="${pulled} ${image}-amd64"
      else 
         fatal "Image pull failed: ${image}, exit, please try to execute again."
      fi         
   done
  info "Creating ${amd64_images_tar} with${pulled}"
  docker save $(echo ${pulled}) | gzip --stdout > ${amd64_images_tar}
}

pull_arm_image () {
  pulled=""
  for image in "${image_list[@]}"
    do
      if docker pull "${image}" --platform=arm64 > /dev/null 2>&1 ; then
         info "Image pull success: ${image}"
         docker tag "${image}" "${image}-arm64"
         pulled="${pulled} ${image}-arm64"
      else
         fatal "Image pull failed: ${image}, exit, please try to execute again."
      fi
   done
  info "Creating ${arm64_images_tar} with${pulled}"
  docker save $(echo ${pulled}) | gzip --stdout > ${arm64_images_tar}
}

push_manifest () {
  export DOCKER_CLI_EXPERIMENTAL=enabled
  docker load --input ${amd64_images_tar}
  if [ $? -ne 0 ]; then
     fatal "Loading amd64 images failed, please try to execute again, or check the images tarball!"
  fi
  docker load --input ${arm64_images_tar}
  if [ $? -ne 0 ]; then
     fatal "Loading arm64 images failed, please try to execute again, or check the images tarball!"
  fi
  for image in "${image_list[@]}"
    do
      if docker tag "${image}-amd64" "$registry/argocd/${image}"
         docker tag "${image}-amd64" "$registry/argocd/${image}-amd64"
         docker tag "${image}-arm64" "$registry/argocd/${image}-arm64"
         docker push "$registry/argocd/${image}-amd64"
         if [ $? -ne 0 ]; then
           fatal "Image push failed: ${registry}/argocd/${image}-amd64, exit, please check and try to execute again."
         fi
         docker push "$registry/argocd/${image}-arm64"
         if [ $? -ne 0 ]; then
           fatal "Image push failed: ${registry}/argocd/${image}-arm64, exit, please check and try to execute again."
         fi
         docker manifest create --insecure --amend "$registry/argocd/${image}" "$registry/argocd/${image}-amd64" "$registry/argocd/${image}-arm64"
         docker manifest push --insecure --purge "$registry/argocd/${image}" ; then
         info "Image manifest push success: ${registry}/argocd/${image}"
      else 
         fatal "Image manifest push failed: ${registry}/argocd/${image}, exit, please try to execute again."
      fi         
   done
}

if [ "$1" = "pull" ]; then
  pull_amd_image
  pull_arm_image
elif [ "$1" = "push" ]; then
  push_manifest ${registry}
else
  warn "Usage: please use mode as ./argocd-images-pull-push.sh pull or ./argo-images-pull-push.sh push registry.example.com"
fi
