package test

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

type hclfilecontent struct {
	Locals []struct {
		Environment            string   `json:"environment"`
		ArtifactAllowListMaven []string `json:"artifact_allow_list_maven"`
		WorkspaceURL           string   `json:"workspace_url"`
		Clusters               map[string]struct {
			AutoterminationMinutes int      `json:"autotermination_minutes"`
			Name                   []string `json:"name"`
			NodeTypeID             string   `json:"node_type_id"`
			RuntimeEngine          string   `json:"runtime_engine"`
			SparkVersion           string   `json:"spark_version"`
			DataSecurityMode       string   `json:"data_security_mode"`
		} `json:"clusters"`
		Pools map[string]struct {
			MaxCapacity      string   `json:"max_capacity"`
			MinIdleInstances string   `json:"min_idle_instances"`
			Name             []string `json:"name"`
			NodeTypeID       string   `json:"node_type_id"`
			SparkVersion     string   `json:"spark_version"`
		} `json:"pools"`
		Sqlwshs map[string]struct {
			AutoStopMins            int      `json:"auto_stop_mins"`
			ClusterSize             string   `json:"cluster_size"`
			EnableServerlessCompute bool     `json:"enable_serverless_compute"`
			Name                    []string `json:"name"`
		} `json:"sqlwsh1"`
	} `json:"locals"`
}

func TestSqlUNIT(t *testing.T) {
	log.Println("********Start unit Test**************")
	cdworkspace := os.Getenv("WORKSPACE")
	branchName := os.Getenv("BRANCH_NAME")
	az_temp := filepath.Join(cdworkspace, ".azure")
	os.Setenv("AZURE_CONFIG_DIR", az_temp)
	// cdworkspace, _ := filepath.Abs("../../../..")
	// branchName := "develop"
	var destination string
	var envName string
	switch {
	case strings.Contains(branchName, "develop"):
		destination = filepath.Join(cdworkspace, "impl", "dataServices", "dev")
		envName = "dev"
	case strings.Contains(branchName, "feature"):
		destination = filepath.Join(cdworkspace, "impl", "dataServices", "sbx")
		envName = "sbx"
	case strings.Contains(branchName, "release"):
		destination = filepath.Join(cdworkspace, "impl", "dataServices", "tst")
		envName = "tst"
	case strings.Contains(branchName, "main"):
		destination = filepath.Join(cdworkspace, "impl", "dataServices", "prd")
		envName = "prd"
	default:
		log.Println("Not a valid branch to run compliance")
	}
	filename := filepath.Join(destination, "env.hcl")
	log.Println(filename)
	outfilename := filepath.Join(destination, "hcljson")
	log.Println(outfilename)
	terraform.HCLFileToJSONFile(filename, outfilename)
	file, _ := os.ReadFile(outfilename)
	var result hclfilecontent
	json.Unmarshal(file, &result)
	for _, j := range result.Locals {
		envNameinHCL := strings.ToUpper(j.Environment)
		for _, k := range j.Sqlwshs {
			sqlNames := k.Name
			for _, j := range sqlNames {
				sqlname := j
				newName := strings.ReplaceAll(sqlname, "${local.env}", envNameinHCL)
				log.Println(newName)
				t.Run("SQL Warehouse name maintains naming convention", func(t *testing.T) {
					a := assert.Contains(t, strings.ToUpper(newName), strings.ToUpper(envName))
					if a == false {
						t.Logf("The name does not have environment value %s", envName)
					} else {
						log.Println("The sqlwhs name have environment value")
					}
				})
			}
			servless := k.EnableServerlessCompute
			t.Run("sqlwhs is serverless", func(t *testing.T) {
				if servless == true {
					log.Println("The warehouse is serverless")
				} else {
					t.Logf("The warehouse is not serverless")
				}
			})
			stopMin := k.AutoStopMins
			t.Run("Sql Warehouse shall have autostopped mins", func(t *testing.T) {
				if stopMin == 0 {
					t.Logf("The warehouse will be always up and running")
				} else {
					log.Println("The warehouse has auto stop enabled")
				}
			})
		}
	}
}
