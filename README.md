# README #

### What is this repository for? ###

### How do I get set up? ###

#### Prereqs ####

Will need local admin to do local development

  * Azure CLI (https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli)
  * Terrafrom (https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
  * Terragrunt (https://terragrunt.gruntwork.io/docs/getting-started/install/)
  * tflint (For local linting: https://github.com/terraform-linters/tflint#installation)
  * Go (For terratest: https://go.dev/doc/install)

#### Local Commands ####

```
## Env inputs
## These will be project specific. Here is example of two secret terrafomr varriables being set.
$env:ANSIBLE_GIT_TOKEN = '<AnsibleRepoToken>'
$env:ANSIBLE_VAULT_PASS = '<VaultPassword>'


## Run all Tests
go test ./... -timeout 1000s -v

## Run specific
go test ./... -timeout 1000s -run <NameofTest> -v
#Examples
go test ./... -timeout 1000s -run TestRGOnlyExample -v
go test ./... -timeout 1000s -run TestRGWithVNetExample -v

## If a test passes locally and you dont make a change it is cached and doesnt rerun. This cleans cache and forces a reruns
go clean -testcache
```

```
## How to run linting
terraform fmt -recursive

tflint <relative_module_path>
tflint .\modules\azure\vnet\
```

```
## Bash Setup
## For cache, set this to avoid windows path char limit.
export TERRAGRUNT_DOWNLOAD=c:/terragrunt_cache

// example secrets to pass terraform from environment variables use get_env("VARIABLENAME") in terragrunt hcl
export TF_variable=<VARIABLENAME>

## Powershell Setup
## For cache, set this to avoid windows path char limit.
$env:TERRAGRUNT_DOWNLOAD = 'c:/terragrunt_cache'

## How to run Deployments
## Depending on where you run from, you get different scope of your action
cd impl/<env> (operates on a whole env)
cd impl/<env>/<cloud> (operates on a whole cloud)
cd impl/<env>/<cloud>/<region> (operates on a whole region)
cd impl/<env>/<cloud>/<module> (operates on a whole module)

## Validate the terraform/grunt setup. This will init testing modules and backend
terragrunt run-all validate

## This will run via a validate, but if you need to regenerate terraform cache and lock files run this
terragrunt run-all init

## if you change a ton of inputs/outputs of modules you may need to run this.
terragrunt run-all refresh

## If you want to run a play to see changes before applying
terragrunt run-all plan
terragrunt run-all apply

## If you want to destroy infrastructure, be aware what directory you are in. It will destroy all within.
terragrunt run-all destroy

```
