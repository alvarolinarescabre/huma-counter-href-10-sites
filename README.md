# huma-counter-href-10-sites 🚀

An example Huma app that fetches and aggregates hrefs from 10 websites, packaged with a Docker image and deployed via a GitOps pipeline using ArgoCD. This repository contains the application code, Kubernetes manifests, and Terraform for a CI/CD pipeline that builds the image and updates ArgoCD manifests.

Highlights:

- 🔧 App: Huma service in `app/`
- 🐳 Container: Dockerfile + ECR integration
- ⚙️ CI/CD: AWS CodePipeline (Source → Build → Deploy) and CodeBuild
- 📦 GitOps: ArgoCD manifests under `gitops/` and ArgoCD Application manifests in Terraform
- 🛠️ Infra-as-code: Terraform modules to provision pipeline, ECR, and integrations

Quick links

- App source: `app/`
- K8s manifests: `gitops/`
- CI/CD terraform: `infrastructure/terraform/`
- Buildspecs: `pipeline/buildspec.yml` (build) and `pipeline/buildspec-execute.yml` (deploy)

Getting started 🏁

Prerequisites:

- AWS account with sufficient permissions
- AWS CLI configured
- Terraform 1.5+ (or the version specified by the repo)
- Optional: GitHub CodeStar connection configured for pipeline source

Local development (quick) — Go + Huma:

Prerequisites:

- Go 1.20+ installed and `GOPATH` properly configured (modules enabled).

Run locally:

1. Change to the `app` folder and download modules:

```bash
cd app
go mod tidy
```

2. Run the server in development mode:

```bash
# run directly (recommended for dev)
go run main.go

# or build a binary and run
go build -o huma-app .
./huma-app
```

3. The server will listen on the port configured in `main.go` (check the code or logs for the exact URL).

Notes:

- This project uses the Huma framework for HTTP handlers. Development uses standard `go run`/`go build` workflows.
- If you change module dependencies, run `go mod tidy` again to keep `go.sum` up to date.

CI / GitOps flow 🧭

- Source: GitHub repository (CodeStar connection) pushes changes to `main`.
- Build: CodeBuild runs `buildspec.yml` to build and push a Docker image to ECR and writes `imagedefinitions.json`.
- Deploy (GitOps): A CodeBuild job (Deploy) runs the repository `buildspec-execute.yml` to update the ArgoCD manifests repository (or a path in this repo). ArgoCD then syncs the Kubernetes cluster.

Notes & security 🔒

- The pipeline can be configured to avoid storing a GitHub PAT in the repo; instead it reads an SSM parameter or can operate anonymously/SSH when possible.
- Terraform manages pipeline resources, but the EKS/cluster and ArgoCD can be managed separately if desired (this repo includes modules to help).

Outputs & helpful commands 🧾

- Update kubeconfig: use the Terraform output `kubeconfig_command` or run:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

- To view pipeline name and CodeBuild projects, run `terraform output` in `infrastructure/terraform`.

Want me to help? 🤝

If you want I can:

- run Terraform plan/apply for the pipeline changes
- trigger a pipeline run to exercise the GitOps flow
- add a CONTRIBUTING or developer guide with detailed steps

---

Created and maintained by the repository owner. ⭐
