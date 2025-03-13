# Vikunja ToDo List - Demo setup on GCP/GKE

This guide automates the deployment of the Vikunja ToDo List application on Google Kubernetes Engine (GKE). It utilizes Terraform for infrastructure provisioning and a Helm chart for streamlined application and database deployment.

## Prerequisites

Before proceeding, ensure you have:

* **CLI Tools:** Terraform, gcloud, kubectl, and Helm installed and configured.
* **Google Cloud Account:** A GCP account with an active project.
* **Cloudflare Domain:** A Cloudflare account with an active domain and DNS management configured for that domain.


## Infrastructure Provisioning

The Terraform code automates the creation of the following resources on GCP and Cloudflare:

* Network: VPC network, subnet, and Static IP.
* Storage: Google Cloud Storage (GCS) bucket for file storage.
* Kubernetes: Google Kubernetes Engine (GKE) cluster, namespaces, and service accounts.
* Observability: Monitoring and logging tools (Prometheus, Grafana, Loki).
* Identity and Access Management (IAM): Service account and IAM roles.
* Certificate management: cert-manager controller
* DNS: Cloudflare DNS record.

Provision the infrastructure by following these steps:

1. Copy the **terraform/sample.tfvars.json** to **terraform/default.tfvars.json**

2. Set the values on **terraform/default.tfvars.json** for:

- GCP_PROJECT_ID
- GCP_REGION
- GCP_ZONE
- GKE_CLUSTER_NAME
- CLOUDFLARE_API_TOKEN
- CLOUDFLARE_ZONE_ID

You can also change other variable values to fit your specific needs.

3. Authenticate with GCP

```bash
gcloud auth application-default login
```

4. Run the following commands on **terraform folder**:

```bash
terraform init
terraform plan -out=default.plan --var-file=tfvars/default.tfvars --var-file=default.tfvars.json
terraform apply default.plan

# Cleanup the resources if not needed anymore 
terraform destroy --var-file=tfvars/default.tfvars --var-file=default.tfvars.json
```

## Deploy the Vikunja application and the database on GKE

1. Connect to the GKE cluster. 

```bash
export GCP_PROJECT_ID=<GCP_PROJECT_ID>
export GCP_REGION=<GCP_REGION>
export GKE_CLUSTER_NAME=<GKE_CLUSTER_NAME>

gcloud container clusters get-credentials $GKE_CLUSTER_NAME --region $GCP_REGION --project $GCP_PROJECT_ID
```

2. Set a URL for **publicURL** at **helmChart/values.yaml** file.

3. Deploy the application and the database using helm

```bash
helm upgrade -i vikunja ./helmChart -n services
```

Finally visit the Vikunja service at the URL as it has beed set at **publicURL** on helmChart/values.yaml. 

4. Enable secure access (optional)

   Enable HTTPS access to Vikunja with the following changes

   4.1 Set the value of **protocol** to **https** at helmChart/values.yaml.

   4.2 Uncomment all lines at helmChart/templates/ingress.yaml, so it will look like this:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.application.appName }}-ingress
  namespace: {{ .Values.application.namespace }}
  annotations:
    kubernetes.io/ingress.global-static-ip-name: {{ .Values.application.ipAddressName }}
    kubernetes.io/ingress.allow-http: "true"
    cert-manager.io/issuer: letsencrypt-{{ .Values.application.appName }}
spec:
  tls:
    - hosts:
        -  {{ .Values.application.publicURL }}
      secretName: {{ .Values.application.appName }}-ingress-tls
  rules:
  - http:
      paths:
      - backend:
          service:
            name: {{ .Values.application.appName }}-svc
            port:
              name: http
        path: /*
        pathType: ImplementationSpecific
```

   4.3 Run the command

```bash
helm upgrade -i vikunja ./helmChart -n services
```

The ingress controller is using cert manager for automated issuance and renewal of certificates to secure Ingress with TLS.


## Connect to Grafana

Run the commands: 

```bash
# get the credentials for grafana
kubectl get secret loki-grafana -o jsonpath="{.data.admin-user}" -n monitoring | base64 --decode
kubectl get secret loki-grafana -o jsonpath="{.data.admin-password}" -n monitoring | base64 --decode

# port forward to the grafana service
kubectl port-forward svc/loki-grafana -n monitoring 8080:80
```

Access Grafana at http://localhost:8080/ using the credentials retrieved from the secrets.


## Network Policies

Optionally, If need to reduce unnecessary network traffic inside the cluster and improve security, then apply the NetworkPolicy in **manifests** folder:

```bash
kubectl apply -f np-ingress.yaml
```