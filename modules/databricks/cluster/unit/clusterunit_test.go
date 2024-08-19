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
			AutoStopMins            int    `json:"auto_stop_mins"`
			ClusterSize             string `json:"cluster_size"`
			EnableServerlessCompute bool   `json:"enable_serverless_compute"`
		} `json:"sqlwsh1"`
	} `json:"locals"`
}

func TestCluster(t *testing.T) {
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
	log.Println("Validate env.hcl file inputs for Cluster")
	for _, j := range result.Locals {
		envNameinHCL := strings.ToUpper(j.Environment)
		for _, k := range j.Clusters {
			clusterNames := k.Name
			idleTime := k.AutoterminationMinutes
			log.Println(idleTime)
			for _, j := range clusterNames {
				name := j
				newName := strings.ReplaceAll(name, "${local.env}", envNameinHCL)
				log.Println(newName)
				t.Run("Cluster name maintains naming convention", func(t *testing.T) {
					a := assert.Contains(t, newName, strings.ToUpper(envName))
					if a == false {
						t.Logf("The name does not have environment value %s", envName)
					} else {
						log.Println("The Cluster name have environment value")
					}
					b := assert.Contains(t, strings.ToUpper(name), strings.ToUpper("cluster"))
					if b == false {
						t.Logf("The name does not have string value CLUSTER")
					} else {
						log.Println("The name have string value CLUSTER")
					}
				})
				Clspark := k.SparkVersion
				t.Run("Runtime version is 13.3", func(t *testing.T) {
					a := assert.Contains(t, Clspark, "13.3")
					if a == false {
						t.Logf("The runtime version is not 13.3 but %s", Clspark)
					} else {
						log.Println("The runtime version is ", Clspark)
					}
				})
				NONUC := strings.Contains(strings.ToUpper(name), "NON")
				if NONUC == false {
					log.Println("CHECKPOINTS FOR Cluster type : UNITY CATALOG")
					// t.Run("Unity Catalog Cluster autotermination minutes is not less than 30", func(t *testing.T) {
					// 	if idleTime >= 30 {
					// 		log.Println("The autotermination minutes is not less than 30")
					// 	} else {
					// 		t.Logf("The autotermination minutes is less than 30")
					// 	}
					// })
					t.Run("Unity Catalog Cluster data security mode is USER_ISOLATION", func(t *testing.T) {
						dsMode := k.DataSecurityMode
						if dsMode == "USER_ISOLATION" {
							log.Println("Security mode is USER_ISOLATION")
						} else {
							t.Logf("Security mode is not USER_ISOLATION but %s", dsMode)
						}
					})
					DBKruntime := k.RuntimeEngine
					t.Run("Unity Catalog Cluster Runtime engine is PHOTON", func(t *testing.T) {
						if DBKruntime == "PHOTON" {
							log.Println("The runtime version is ", DBKruntime)
						} else {
							t.Logf("The runtime engine is not PHOTON but %s", DBKruntime)
						}
					})
				}
			}
		}
	}
}
