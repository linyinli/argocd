# Custom ArgoCD Chart

在 Rancher 平台上集成 ArgoCD 的部署包，修改以下自定义配置：
- 提供 ArgoCD 下载上传脚本
- ArgoCD 采用 HA 高可用部署
- 使用内网镜像仓库地址
- 使用 Ingress 域名访问
- 自定义 ArgoCD 的 RBAC 权限，默认只读，需要对 Namespace 进行发布时，在该 Namespace 范围内对 argocd 授予 cluster-admin 权限
