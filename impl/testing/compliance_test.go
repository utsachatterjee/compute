package test

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/databricks/databricks-sdk-go"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"golang.org/x/exp/slices"
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
		PoolIdleInstanceAutoterminationMinutes int `json:"pool_idle_instance_autotermination_minutes"`
		Pools                                  map[string]struct {
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

func TestIntegration_databricksstack(t *testing.T) {
	log.Println("********Start Compliance Test**************")
	cdworkspace := os.Getenv("WORKSPACE")
	branchName := os.Getenv("BRANCH_NAME")
	az_temp := filepath.Join(cdworkspace, ".azure")
	os.Setenv("AZURE_CONFIG_DIR", az_temp)
	// cdworkspace, _ := filepath.Abs("../..")
	// branchName := "develop"
	var impldirPath string
	switch {
	case strings.Contains(branchName, "develop"):
		impldirPath = filepath.Join(cdworkspace, "impl", "dev")
	case strings.Contains(branchName, "feature"):
		impldirPath = filepath.Join(cdworkspace, "impl", "sbx")
	case strings.Contains(branchName, "release"):
		impldirPath = filepath.Join(cdworkspace, "impl", "tst")
	case strings.Contains(branchName, "main"):
		impldirPath = filepath.Join(cdworkspace, "impl", "prd")
	default:
		log.Println("Not a valid branch to run compliance")
	}
	//Get directory path to fetch directory name.
	dirtolist := filepath.Join(impldirPath, "azure", "databricks")
	log.Println("Directory to list: ", dirtolist)
	files, err := os.ReadDir(dirtolist)
	if err != nil {
		log.Fatal(err)
	}
	//List directory names
	for _, v := range files {
		if v.IsDir() == true {
			name := v.Name()
			fmt.Println(name)
			//Run test based on directory type
			switch name {
			case "artifact":
				ARTIFACT(t, impldirPath)

			case "cluster":
				CLUSTER(t, impldirPath, dirtolist)

			case "pool":
				POOL(t, impldirPath, dirtolist)

			case "sqlwarehouse":
				SQLWSH(t, impldirPath, dirtolist)

			default:
				log.Println("No case found")
			}
		}
	}
}

func ARTIFACT(t *testing.T, a string) {
	log.Println("***********Checking artifact allowlist*******************")
	pathToEnvHCL := a
	hclJsonResponse := ParseAndFetch(pathToEnvHCL)
	urlname := hclJsonResponse.Locals[0].WorkspaceURL
	log.Println("HOST: ", urlname)
	artifactNames := hclJsonResponse.Locals[0].ArtifactAllowListMaven
	wkspc, err := databricks.NewWorkspaceClient(&databricks.Config{
		Host: urlname,
	})
	ctx := context.Background()
	if err != nil {
		log.Fatalln("Could not connect to host:", err)
	}
	lists, err := wkspc.ArtifactAllowlists.GetByArtifactType(ctx, "LIBRARY_MAVEN")
	if err != nil {
		log.Fatalln("Could not fetch Maven allowlist from Metastore:", err)
	}
	for _, elem := range lists.ArtifactMatchers {
		name := elem.Artifact
		name += " present in allowlist in Metastore"
		t.Run(name, func(t *testing.T) {
			expname := elem.Artifact
			a := slices.Contains(artifactNames, expname)
			if a == true {
				log.Printf("%s is present in Allow list", expname)
			} else {
				t.Errorf("%s is not present in Allow list", expname)
			}
		})
	}
}

func CLUSTER(t *testing.T, a string, b string) {
	log.Println("***********Checking Cluster*******************")
	pathToEnvHCL := a
	hclJsonResponse := ParseAndFetch(pathToEnvHCL)
	urlname := hclJsonResponse.Locals[0].WorkspaceURL
	log.Println("HOST: ", urlname)
	clusterdest := filepath.Join(b, "cluster")
	//initialize cluster terraform directory
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    clusterdest,
		TerraformBinary: "terragrunt",
	})
	//fetch cluster ouput from module
	clsoutput := terraform.OutputJson(t, terraformOptions, "clusterNames")
	var abc []string
	json.Unmarshal([]byte(clsoutput), &abc)
	ctx := context.Background()
	wkspc, err := databricks.NewWorkspaceClient(&databricks.Config{
		Host: urlname,
	})
	if err != nil {
		t.Errorf("Unable to create connection to cloud %v", err)
	}
	for _, k := range abc {
		name := k
		name += " exists in cloud"
		t.Run(name, func(t *testing.T) {
			expname := k
			output, err := wkspc.Clusters.GetByClusterName(ctx, expname)
			if err != nil {
				t.Errorf("Unable to fetch cluster %v", err)
			}
			actualname := output.ClusterName
			a := assert.Equal(t, expname, actualname)
			if a != true {
				t.Errorf("%s is not present in Cloud", actualname)
			} else {
				log.Printf("%s Exists in Cloud", actualname)
				log.Println("Checking all properties")
				for _, ids := range hclJsonResponse.Locals {
					for _, elem := range ids.Clusters {
						envNameinHCL := strings.ToUpper(ids.Environment)
						nameList := replaceitems(elem.Name, envNameinHCL)
						matchList := slices.Contains(nameList, strings.ToUpper(actualname))
						if matchList == true {
							t.Run("Autotermination minutes", func(t *testing.T) {
								exptermination := elem.AutoterminationMinutes
								actualtermination := output.AutoterminationMinutes
								assert.Equal(t, exptermination, actualtermination, "Value should match env.hcl file")
							})
							t.Run("Data Security Mode", func(t *testing.T) {
								expdsmode := elem.DataSecurityMode
								actualdsmode := output.DataSecurityMode.String()
								assert.Equal(t, expdsmode, actualdsmode, "Value should match env.hcl file")
							})
							t.Run("Spark Version", func(t *testing.T) {
								expspark := elem.SparkVersion
								actualspark := output.SparkVersion
								assert.Equal(t, expspark, actualspark, "Value should match env.hcl file")
							})
							t.Run("Node Type", func(t *testing.T) {
								expdnode := elem.NodeTypeID
								actualnode := output.NodeTypeId
								assert.Equal(t, expdnode, actualnode, "Value should match env.hcl file")
							})
							t.Run("Runtime Engine", func(t *testing.T) {
								expdeng := elem.RuntimeEngine
								actualeng := output.RuntimeEngine.String()
								assert.Equal(t, expdeng, actualeng, "Value should match env.hcl file")
							})
						}
					}
				}
			}
		})
	}
}

func POOL(t *testing.T, a string, b string) {
	log.Println("***********Checking Pool*******************")
	pathToEnvHCL := a
	hclJsonResponse := ParseAndFetch(pathToEnvHCL)
	urlname := hclJsonResponse.Locals[0].WorkspaceURL
	log.Println("HOST: ", urlname)
	//initialize cluster terraform directory
	pooldest := filepath.Join(b, "pool")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    pooldest,
		TerraformBinary: "terragrunt",
	})
	//fetch cluster ouput from module
	clsoutput := terraform.OutputJson(t, terraformOptions, "poolNames")
	var abc []string
	json.Unmarshal([]byte(clsoutput), &abc)
	ctx := context.Background()
	wkspc, err := databricks.NewWorkspaceClient(&databricks.Config{
		Host: urlname,
	})
	if err != nil {
		t.Errorf("Unable to create connection to cloud %v", err)
	}
	for _, k := range abc {
		name := k
		name += " exists in cloud"
		t.Run(name, func(t *testing.T) {
			expname := k
			output, err := wkspc.InstancePools.GetByInstancePoolName(ctx, expname)
			if err != nil {
				t.Errorf("Unable to fetch pool %v", err)
			}
			actualname := output.InstancePoolName
			a := assert.Equal(t, expname, actualname)
			if a != true {
				t.Errorf("%s is not present in cloud", actualname)
			} else {
				log.Printf("%s is present in cloud", actualname)
				log.Println("Checking all properties")
				for _, ids := range hclJsonResponse.Locals {
					for _, elem := range ids.Pools {
						envNameinHCL := strings.ToUpper(ids.Environment)
						nameList := replaceitems(elem.Name, envNameinHCL)
						matchList := slices.Contains(nameList, strings.ToUpper(actualname))
						if matchList == true {
							t.Run("Min Idle Instance", func(t *testing.T) {
								expMinIdleInstances := elem.MinIdleInstances
								actualMinIdleInstances := strconv.Itoa(output.MinIdleInstances)
								assert.Equal(t, expMinIdleInstances, actualMinIdleInstances, "Value should match env.hcl file")
							})
							t.Run("Max Capacity", func(t *testing.T) {
								expMC := elem.MaxCapacity
								actualMC := strconv.Itoa(output.MaxCapacity)
								assert.Equal(t, expMC, actualMC, "Value should match env.hcl file")
							})
							t.Run("Spark Version", func(t *testing.T) {
								expspark := elem.SparkVersion
								actualspark := output.PreloadedSparkVersions[0]
								assert.Equal(t, expspark, actualspark, "Value should match env.hcl file")
							})
							t.Run("Node Type", func(t *testing.T) {
								expdnode := elem.NodeTypeID
								actualnode := output.NodeTypeId
								assert.Equal(t, expdnode, actualnode, "Value should match env.hcl file")
							})
							t.Run("Runtime Engine", func(t *testing.T) {
								expterm := ids.PoolIdleInstanceAutoterminationMinutes
								actualterm := output.IdleInstanceAutoterminationMinutes
								assert.Equal(t, expterm, actualterm, "Value should match env.hcl file")
							})
						}
					}
				}
			}
		})
	}
}

func SQLWSH(t *testing.T, a string, b string) {
	log.Println("***********Checking sqlwarehouse*******************")
	pathToEnvHCL := a
	hclJsonResponse := ParseAndFetch(pathToEnvHCL)
	urlname := hclJsonResponse.Locals[0].WorkspaceURL
	//initialize cluster terraform directory
	sqldest := filepath.Join(b, "sqlwarehouse")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    sqldest,
		TerraformBinary: "terragrunt",
	})
	//fetch cluster ouput from module
	clsoutput := terraform.OutputJson(t, terraformOptions, "sqlwhNames")
	var abc []string
	json.Unmarshal([]byte(clsoutput), &abc)
	ctx := context.Background()
	wkspc, err := databricks.NewWorkspaceClient(&databricks.Config{
		Host: urlname,
	})
	if err != nil {
		t.Errorf("Unable to create connection to cloud %v", err)
	}
	for _, k := range abc {
		name := k
		name += " exists in cloud"
		t.Run(name, func(t *testing.T) {
			expname := k
			output, err := wkspc.Warehouses.GetByName(ctx, expname)
			if err != nil {
				t.Errorf("Unable to fetch warehouse %v", err)
			}
			actualname := output.Name
			a := assert.Equal(t, expname, actualname)
			if a == true {
				log.Printf("%s is present in cloud", actualname)
			} else {
				t.Errorf("%s is not present in cloud", actualname)
			}
		})
	}
}

func replaceitems(a []string, b string) []string {
	list := a
	envName := b
	for i, each := range list {
		original := each
		new := strings.ToUpper(strings.ReplaceAll(original, "${local.env}", envName))
		list[i] = new
	}
	log.Println(list)
	return list
}

func ParseAndFetch(a string) hclfilecontent {
	destinationenvhcl := a
	infilename := filepath.Join(destinationenvhcl, "env.hcl")
	outfilename := filepath.Join(destinationenvhcl, "hcljson")
	terraform.HCLFileToJSONFile(infilename, outfilename)
	file, _ := os.ReadFile(outfilename)
	var result hclfilecontent
	json.Unmarshal(file, &result)
	return result
}
