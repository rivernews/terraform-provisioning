# Based on
# https://artifacthub.io/packages/helm/prometheus-worawutchan/kube-prometheus-stack
resource "helm_release" "prometheus_stack" {
  name      = "prometheus-stack-release"
  namespace = kubernetes_service_account.tiller.metadata.0.namespace

  force_update = true
  # Based on
  # https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md
  # Successful example
  # https://github.com/hashicorp/terraform-provider-helm/issues/585#issuecomment-707379744
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  values = [<<-EOF
    defaultRules:
        rules:
            kubernetesResources:
                limits:
                    memory: "600Mi"

    prometheusOperator:
      admissionWebhooks:
        patch:
          nodeSelector:
            "doks.digitalocean.com/node-pool": ${data.digitalocean_kubernetes_cluster.project_digitalocean_cluster.node_pool.0.name}
      nodeSelector:
        "doks.digitalocean.com/node-pool": ${data.digitalocean_kubernetes_cluster.project_digitalocean_cluster.node_pool.0.name}
      # for debug purpose
      # this should replace del-crd.sh, can delete the script
      cleanupCustomResource: true

    prometheus:
      prometheusSpec:
        nodeSelector:
          "doks.digitalocean.com/node-pool": ${data.digitalocean_kubernetes_cluster.project_digitalocean_cluster.node_pool.0.name}

    alertmanager:
      alertmanagerSpec:
        nodeSelector:
          "doks.digitalocean.com/node-pool": ${data.digitalocean_kubernetes_cluster.project_digitalocean_cluster.node_pool.0.name}

    grafana:
      ingress:
        enabled: true
        annotations:
          kubernetes.io/ingress.class: "nginx"
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        hosts:
          - "grafana.shaungc.com"
        tls:
          - hosts:
            - "grafana.shaungc.com"
      adminPassword: "${data.aws_ssm_parameter.grafana_credentials.value}"
  EOF
  ]

  depends_on = [
    # add the binding as dependency to avoid error below (due to binding deleted prior to refreshing / altering this resource)
    # Error: rpc error: code = Unknown desc = configmaps is forbidden: User "system:serviceaccount:kube-system:tiller-service-account" cannot list resource "configmaps" in API group "" in the namespace "kube-system"
    #
    # Way to debug such error: https://github.com/helm/helm/issues/5100#issuecomment-533787541
    kubernetes_cluster_role_binding.tiller,
  ]
}

data "aws_ssm_parameter" "grafana_credentials" {
  name  = "/service/grafana/ADMIN_PASSWORD"
}
