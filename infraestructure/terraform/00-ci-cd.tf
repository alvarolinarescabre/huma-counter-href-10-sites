
################################################################################
# ECR Repository - huma-counter-href-10-sites
################################################################################

resource "aws_ecr_repository" "app" {
  name                 = "huma-counter-href-10-sites"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = local.name
  }
}

################################################################################
# Secrets Manager - placeholder for GITHUB token used by deploy CodeBuild
################################################################################

resource "aws_secretsmanager_secret" "app_deploy_github_token" {
  name        = "${local.name}-app-deploy-github-token"
  description = "GitHub token for pushing ArgoCD manifests from app_deploy CodeBuild. Set secret value via AWS console or CLI."

  tags = {
    Project = local.name
  }
}

# If the token value is provided via Terraform variable, create a secret version
resource "aws_secretsmanager_secret_version" "app_deploy_github_token_value" {
  count = var.app_deploy_github_token != "" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.app_deploy_github_token.id
  secret_string = var.app_deploy_github_token
}


resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

################################################################################
# S3 Bucket - App Pipeline Artifacts
################################################################################

resource "aws_s3_bucket" "app_pipeline_artifacts" {
  bucket        = "${local.name}-app-pipeline-artifacts"
  force_destroy = true

  tags = {
    Project = local.name
  }
}

resource "aws_s3_bucket_versioning" "app_pipeline_artifacts" {
  bucket = aws_s3_bucket.app_pipeline_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

################################################################################
 # CodeStar Connection - GitHub (used by app pipeline)
################################################################################

resource "aws_codestarconnections_connection" "github" {
  name          = "${local.name}-github"
  provider_type = "GitHub"

  tags = {
    Project = local.name
  }
}

################################################################################
# SSM Parameter - GitHub Token
################################################################################

/* Removed SSM github_token parameter — repository is public and no token is required */

################################################################################
# IAM Role - CodeBuild App (Docker Build)
################################################################################

resource "aws_iam_role" "codebuild_app" {
  name = "${local.name}-codebuild-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = local.name
  }
}

resource "aws_iam_role_policy" "codebuild_app" {
  name = "${local.name}-codebuild-app-policy"
  role = aws_iam_role.codebuild_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_pipeline_artifacts.arn,
          "${aws_s3_bucket.app_pipeline_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "ECR"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "CodeStarConnections"
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = aws_codestarconnections_connection.github.arn
      },
      # SSM access removed (no GITHUB token required for public repo)
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "${aws_secretsmanager_secret.app_deploy_github_token.arn}"
      }
    ]
  })
}

################################################################################
# CodeBuild - Docker Build & Push to ECR
################################################################################

resource "aws_codebuild_project" "app_build" {
  name          = "${local.name}-app-build"
  description   = "Build and push Docker image for huma-counter-href-10-sites"
  service_role  = aws_iam_role.codebuild_app.arn
  build_timeout = 30

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.app.repository_url
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "APP_GITHUB_REPO"
      value = var.app_github_repo
    }
    # No GITHUB_TOKEN environment variable — repo is public
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE"
  }

  tags = {
    Project = local.name
  }
}

################################################################################
# CodeBuild - Deploy: update ArgoCD repo manifests (reads imagedefinitions.json)
################################################################################

resource "aws_codebuild_project" "app_deploy" {
  name          = "${local.name}-app-deploy"
  description   = "Run ArgoCD update to push new image references to ArgoCD repo"
  service_role  = aws_iam_role.codebuild_app.arn
  build_timeout = 10

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    environment_variable {
      name  = "ARGOCD_REPO"
      value = var.argocd_manifests_repo
    }
    environment_variable {
      name  = "APP_GITHUB_REPO"
      value = var.app_github_repo
    }
    environment_variable {
      name  = "ARGOCD_APP_NAME"
      value = split("/", var.app_github_repo)[1]
    }
    environment_variable {
      name  = "ARGOCD_PUSH_BRANCH"
      value = var.github_branch
    }
    # GITHUB token (from Secrets Manager) - placeholder secret created below
    environment_variable {
      name  = "GITHUB_TOKEN"
      value = aws_secretsmanager_secret.app_deploy_github_token.arn
      type  = "SECRETS_MANAGER"
    }
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  source {
    type      = "CODEPIPELINE"
    # If `deploy_buildspec_name` is provided, set that filename as the Buildspec name
    # (CodeBuild will look for this file in the source). Otherwise leave unset
    # so CodeBuild will use the repository's default `buildspec.yml`.
    buildspec = var.deploy_buildspec_name != "" ? var.deploy_buildspec_name : null
  }

  tags = {
    Project = local.name
  }

}

################################################################################
# IAM Role - CodePipeline App
################################################################################

resource "aws_iam_role" "codepipeline_app" {
  name = "${local.name}-codepipeline-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = local.name
  }
}

resource "aws_iam_role_policy" "codepipeline_app" {
  name = "${local.name}-codepipeline-app-policy"
  role = aws_iam_role.codepipeline_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_pipeline_artifacts.arn,
          "${aws_s3_bucket.app_pipeline_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "CodeBuild"
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = [
          aws_codebuild_project.app_build.arn,
          aws_codebuild_project.app_deploy.arn
        ]
      },
      {
        Sid    = "CodeStarConnections"
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

################################################################################
# CodePipeline - App (Docker Build + Terraform Apply)
################################################################################

resource "aws_codepipeline" "app" {
  name          = "${local.name}-app-pipeline"
  role_arn      = aws_iam_role.codepipeline_app.arn
  pipeline_type = "V2"

  artifact_store {
    type = "S3"
    location = aws_s3_bucket.app_pipeline_artifacts.bucket
  }

  # Trigger: Run pipeline when PR is merged to main on the app repo
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "App_Source"
      push {
        branches {
          includes = ["main"]
        }
      }
    }
  }

  # Stage 1: Source from GitHub (app repo + infra repo)
  stage {
    name = "Source"

    action {
      name             = "App_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["app_source"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.app_github_repo
        BranchName       = var.github_branch
      }
    }

    # Infra_Source removed — pipeline uses only App_Source as source
  }

  # Stage 2: Build Docker Image & Push to ECR
  stage {
    name = "Build"

    action {
      name             = "Docker_Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["app_source"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
        PrimarySource = "app_source"
      }
    }
  }

  # Stage 3: Deploy - run CodeBuild to update ArgoCD repo (GitOps)
  stage {
    name = "Deploy"

    action {
      name             = "Update_ArgoCD"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
          # Make app_source the primary artifact so CodeBuild can read the repo buildspec (buildspec-execute.yml)
          # and still receive `imagedefinitions.json` via the `build_output` artifact.
          input_artifacts  = ["app_source", "build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.app_deploy.name
        PrimarySource = "app_source"
      }
    }
  }

  tags = {
    Project = local.name
  }
}
