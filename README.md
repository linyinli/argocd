# Custom ArgoCD Chart

在 Rancher 上集成 ArgoCD 的部署包，修改以下自定义配置：
- 提供 ArgoCD 镜像下载上传脚本 ```argocd-images-pull-push.sh```
- ArgoCD 使用 HA 高可用部署
- 使用内网镜像仓库地址
- 使用 Ingress 域名访问，配置 SSL Passthrough
- 自定义 ArgoCD 的 RBAC 权限，默认只读，需要对 Namespace 进行发布时，在该 Namespace 范围内对 argocd 授予 cluster-admin 权限：

```shell
kubectl create rolebinding -n app argocd-application-controller-rb --clusterrole=cluster-admin --serviceaccount=argocd:argocd-application-controller
```

如果需要声明式且对授权的 Namespace 进行记录，参考以下 YAML 文件进行创建，使用时替换 Namespace：

```yaml
  apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-application-controller-rb
  namespace: app
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
  namespace: argocd
```
