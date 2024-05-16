terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "postgres" {
  metadata {
    name = "postgres"
  }
}

resource "kubernetes_namespace" "mlflow" {
  metadata {
    name = "mlflow"
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
    namespace = "postgres"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = "postgres"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        volume {
          name = "postgres-storage"

          persistent_volume_claim {
            claim_name = "postgres-pvc"
          }
        }

        container {
          name  = "postgres"
          image = "postgres:13"

          port {
            container_port = 5432
          }

          env {
            name  = "POSTGRES_DB"
            value = "mlflowdb"
          }

          env {
            name  = "POSTGRES_USER"
            value = "mlflow"
          }

          env {
            name  = "POSTGRES_PASSWORD"
            value = "mlflowpassword"
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = "postgres"
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 5432
      target_port = "5432"
    }

    selector = {
      app = "postgres"
    }
  }
}

resource "kubernetes_persistent_volume_claim" "mlflow_pvc" {
  metadata {
    name      = "mlflow-pvc"
    namespace = "mlflow"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_config_map" "mlflow_config" {
  metadata {
    name      = "mlflow-config"
    namespace = "mlflow"
  }

  data = {
    artifact-root = "/mlflow/artifacts"

    backend-store-uri = "postgresql://mlflow:mlflowpassword@postgres:5432/mlflowdb"
  }
}

resource "kubernetes_deployment" "mlflow" {
  metadata {
    name      = "mlflow"
    namespace = "mlflow"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mlflow"
      }
    }

    template {
      metadata {
        labels = {
          app = "mlflow"
        }
      }

      spec {
        volume {
          name = "mlflow-storage"

          persistent_volume_claim {
            claim_name = "mlflow-pvc"
          }
        }

        container {
          name  = "mlflow"
          image = "mlflow:latest"

          port {
            container_port = 5000
          }

          env {
            name = "BACKEND_STORE_URI"

            value_from {
              config_map_key_ref {
                name = "mlflow-config"
                key  = "backend-store-uri"
              }
            }
          }

          env {
            name = "ARTIFACT_ROOT"

            value_from {
              config_map_key_ref {
                name = "mlflow-config"
                key  = "artifact-root"
              }
            }
          }

          volume_mount {
            name       = "mlflow-storage"
            mount_path = "/mlflow"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mlflow_service" {
  metadata {
    name      = "mlflow-service"
    namespace = "mlflow"
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 443
      target_port = "5000"
    }

    selector = {
      app = "mlflow"
    }
  }
}

resource "kubernetes_manifest" "mlflow_virtualservice" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "mlflow-virtualservice"
      namespace = "mlflow"
    }
    spec = {
      gateways = ["kubeflow/kubeflow-gateway"]
      hosts    = ["*"]
      http = [{
        match = [{
          uri = {
            prefix = "/mlflow/"
          }
        }]
        rewrite = {
          uri = "/"
        }
        route = [{
          destination = {
            host = "mlflow-service.mlflow.svc.cluster.local"
            port = {
              number = 443
            }
          }
        }]
      }]
    }
  }
}