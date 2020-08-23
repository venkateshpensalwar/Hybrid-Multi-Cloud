provider "kubernetes" {
  version = "~>1.12"
  config_context = "minikube"
}

resource "kubernetes_persistent_volume_claim" "PVC" {
  metadata {
    name = "pvc"
    labels = {
        app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_service" "service" {
  metadata {
    name = "wordpress-service"
    labels = {
        app = "wordpress"
    }
  }
  spec {
      selector = {
          app = "wordpress"
          tier = "frontend"
      }
          type = "NodePort"

      port {
                protocol ="TCP"
                node_port ="31000"
                port = "80"
        }
    }
  
}

resource "kubernetes_deployment" "deployment" {
  depends_on = [kubernetes_persistent_volume_claim.PVC]

  metadata {
    name = "wordpress"
    labels = {
    app ="wordpress"
    }
  }

    spec {
      replicas = 2
       strategy {
        type = "Recreate"
       }
        selector {
            match_labels = {
                app: "wordpress"
                tier: "frontend"
            }
        }
        template {
            metadata {
                labels = {
                    app = "wordpress"
                    tier ="frontend"
                }
            }
                spec {
                     volume {
                       name = "wordpressvolume"
                      persistent_volume_claim {
                         claim_name = kubernetes_persistent_volume_claim.PVC.metadata.0.name
                       }
          
                     }
                     container {
                            image = "wordpress:4.8-apache"
                            name  = "wordpress"

                            port {
                              container_port = 80
                              name = "wordpress"
                            }

                           volume_mount {
                              name = "wordpressvolume"
                              mount_path = "/var/www/html"
                           }
                        }               
        }
      }
    }
}