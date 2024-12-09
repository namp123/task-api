provider "google" {
  credentials = file("<path-to-your-service-account-key>.json")
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

#SECRET MANAGER-----------------------------------


# Store MongoDB Username in Secret Manager
resource "google_secret_manager_secret" "mongodb_username" {
  name = "mongodb-username"

  replication {
    automatic = true #stores across different AZ for high availability
  }
}

# Add a Secret Version for the username (This is where the Actual Value of the db username goes)
resource "google_secret_manager_secret_version" "mongodb_username_version" {
  secret      = google_secret_manager_secret.mongodb_username.id
  secret_data = var.mongodb_username # Pass this securely via Terraform variable
}

# Store MongoDB Password in Secret Manager
resource "google_secret_manager_secret" "mongodb_password" {
  name = "mongodb-password"

  replication {
    automatic = true #stores across different AZ for high availability
  }
}

# Add a Secret Version for the password (This is where the Actual Value of the db password goes)
resource "google_secret_manager_secret_version" "mongodb_password_version" {
  secret      = google_secret_manager_secret.mongodb_password.id
  secret_data = var.mongodb_password # Pass this securely via Terraform variable
}

# Grant Access for the Instance Service Account to Secrets
resource "google_secret_manager_secret_iam_member" "mongodb_secret_access" {
  for_each = toset(["mongodb-username", "mongodb-password"])

  secret_id = google_secret_manager_secret[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.instance_service_account_email}" # Replace with your instance's service account email
}

#INSTANCE AND AUTOSCALING GROUP-----------------------------


#Compute Instance for task-Api app to run on
resource "google_compute_instance_template" "nodejs_template" {
  name         = "nodejs-instance-template"
  machine_type = "n1-standard-1"
  region       = var.region
  tags = ["allow-ssh"] #these instances have this firewall rule applied onto them.

#the script needed to initalise any updates on the instance before it can run the app
  metadata_startup_script = <<-EOT 
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y nodejs npm docker.io jq nginx certbot python3-certbot-nginx
    # Creating a non-root user to run Docker containers
    sudo useradd -m -s /bin/bash dockeruser
    sudo usermod -aG docker dockeruser
    # Fetch secrets from Google Secret Manager
    MONGODB_USERNAME=$(gcloud secrets versions access latest --secret="mongodb-username")
    MONGODB_PASSWORD=$(gcloud secrets versions access latest --secret="mongodb-password")
    # Export credentials as environment variables for Docker Compose
    export MONGODB_USERNAME=$MONGODB_USERNAME
    export MONGODB_PASSWORD=$MONGODB_PASSWORD
    git clone https://github.com/your-username/your-nodejs-app.git
    cd your-nodejs-app
    npm install
    pm2 start server.js #start app and it keeps the app from encountering SIGHUP and keeps it running forever
    sudo -u dockeruser docker-compose up -d #start the app and db containers as dockeruser and not root user

    #configuring Nginx for reverse proxy
    cat <<EOF>> /etc/nginx/sites-available/default_service
    server {
        listen 80;
        server_name task-api.com www.task-api.com #domain name not purchased yet and A record needs to be created
        location / {
            proxy_pass http://127.0.0.1:3000
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
    EOF
    systemctl restart nginx

    #generating SSL Certificate
    certbot --nginx -d task-api.com -d www.task-api.com

    #automatic renewal of certbot credentials
    echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | sudo tee -a /etc/crontab
  EOT
}

#SSL certificate resource
resource "google_compute_ssl_certificate" "nodejs_ssl_cert" {
  name        = "nodejs-ssl-cert"
  private_key = file("<path-to-private-key>.pem") 
  certificate = file("<path-to-certificate>.crt") 
}

#HTTPS Termination for load balancer so that it doesnt have to use ssl once inside the cluster
resource "google_compute_target_https_proxy" "nodejs_https_proxy" {
  name             = "nodejs-https-proxy"
  url_map          = google_compute_url_map.nodejs_url_map.id
  ssl_certificates = [google_compute_ssl_certificate.nodejs_ssl_cert.id]
}

#Creating Auto-scaling Group
resource "google_compute_instance_group_manager" "nodejs_manager" {
  name                    = "nodejs-instance-group"
  instance_template       = google_compute_instance_template.nodejs_template.id
  target_size             = 2 #runs 2 instance at all times initially
  zone                    = var.zone
   
  #autoscaling based on CPU/MEM utilization 
  autoscaler {
    target_cpu_utilization = 0.75  # add replicas if it crosses 75%
    target_memory_utilization = 0.75 #adds replicas if it crosses 75%
    min_num_replicas       = 2      # Min 2 replicas
    max_num_replicas       = 10     # Max 10 replicas
  }

}

#LOAD BALANCER-----------------------------


# Global IP Address for Load Balancer to make it accessible or reachable to the internet
resource "google_compute_global_address" "nodejs_lb_ip" {
  name = "nodejs-lb-ip"
}

# Backend service for Load Balancer so that traffic can be sent from LB next to the instances
resource "google_compute_backend_service" "nodejs_backend" {
  name        = "nodejs-backend"
  protocol    = "HTTP"
  backends {
    group = google_compute_instance_group_manager.nodejs_manager.instance_group
  }
  health_checks = [google_compute_health_check.nodejs_health_check.id] #can monitor the health of the 2 vms using the LB
}

# URL Map for Load Balancer to route incoming HTTP(S) requests to the appropriate backend service based on the URL path (eg: /tasks/* could be routed to just one vm if required)
resource "google_compute_url_map" "nodejs_url_map" {
  name            = "nodejs-url-map"
  default_service = google_compute_backend_service.nodejs_backend.id
}

# HTTP Proxy for Load Balancer is what sends incoming HTTPS requests to the appropriate backend services/vms
resource "google_compute_target_http_proxy" "nodejs_http_proxy" {
  name    = "nodejs-http-proxy"
  url_map = google_compute_url_map.nodejs_url_map.id
}

# Forwarding Rule for Load Balancer defines the port forwarding rules to send it to destination, eg: to port 3000 of the vm
resource "google_compute_global_forwarding_rule" "nodejs_forwarding_rule" {
  name       = "nodejs-forwarding-rule"
  ip_address = google_compute_global_address.nodejs_lb_ip.address
  target     = google_compute_target_http_proxy.nodejs_http_proxy.id
  port_range = "443" #uses HTTPS
}

# Firewall Rule to Restrict SSH Access
resource "google_compute_firewall" "restrict_ssh_access" {
  name    = "restrict-ssh-access" #name of this firewall rule
  network = "default" #replace with actual VPC network name

  allow {
    protocol = "tcp"
    ports    = ["22"] # SSH port
  }

  source_ranges = ["203.0.113.0/24", "198.51.100.0/24"] # sample allowed IP ranges
  direction     = "INGRESS" #this rule is for incoming traffic
  target_tags   = ["allow-ssh"] # Add this tag to instances if you want to apply the rule on to those instances
}
#so instances tagged with "allow-ssh" allows incoming TCP traffic to its ssh port 22 from machines in 203.0.113.0/24 and 198.51.100.0/24 range

# Health Check for Auto-scaling (checking app health)
resource "google_compute_health_check" "nodejs_health_check" {
  name               = "nodejs-health-check"
  http_health_check {
    port        = 3000
    request_path = "/"
  }
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}


#MANAGED DATABASE-----------------------------


# MongoDB Atlas Cluster (Managed Database)
resource "mongodbatlas_cluster" "mongodb_cluster" {
  project_id = var.mongodb_project_id
  name       = "nodejs-mongo-cluster"
  cluster_type = "REPLICASET"
  provider_name = "GCP"
  region_name   = var.mongodb_region

  replication_factor = 3 #making db HA as well
  mongo_db_version   = "4.4"

  provider {
    name = "GCP"
    instance_size_name = "M10"
    region_name        = var.mongodb_region
  }
}



#OUTPUT VARIABLES-------------------------------
output "load_balancer_ip" {
  value = google_compute_global_address.nodejs_lb_ip.address
}

output "mongodb_cluster_connection_string" {
  value = mongodbatlas_cluster.mongodb_cluster.connection_strings[0] #the same connection string used in the nodeJS app
}
