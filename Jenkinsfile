pipeline {
    agent {
        node {
            label 'linux'
        }
    }
    options {
        buildDiscarder logRotator(daysToKeepStr: '14', numToKeepStr: '5')
        skipDefaultCheckout(true)
    }
    parameters {
        separator name: "DESTROY_IMPLEMENTATION", sectionHeader: "Destroy Implementation", separatorStyle: "border-width: 0", sectionHeaderStyle: """background-color: #ec7063; text-align: center padding: 4px; color: #343434; font-size: 22px; font-weight: normal; text-transform: uppercase; font-family: 'Orienta', sans-serif; letter-spacing: 1px; font-style: italic;"""
        booleanParam (description: 'Check if you want to destroy resources related to your features or environments', name: 'TERRAGRUNT_DESTROY', defaultValue: false)
        string description: 'Input the implementation name you wish to destroy', name: 'IMPLEMENTATION_TO_DESTROY', trim: true
        separator name: "DEPLOY_IMPLEMENTATION", sectionHeader: "Deploy Implementation", separatorStyle: "border-width: 0", sectionHeaderStyle: """background-color: #7ea6d3; text-align: center padding: 4px; color: #343434; font-size: 22px; font-weight: normal; text-transform: uppercase; font-family: 'Orienta', sans-serif; letter-spacing: 1px; font-style: italic;"""
        string description: 'Input the implementation name you wish to deploy', name: 'IMPLEMENTATION_TO_DEPLOY', trim: true
        separator name: "RUN_ALL_IMPLEMENTATIONS", sectionHeader: "Deploy All Implementations", separatorStyle: "border-width: 0", sectionHeaderStyle: """background-color: #dbdb8e; text-align: center padding: 4px; color: #343434; font-size: 22px; font-weight: normal; text-transform: uppercase; font-family: 'Orienta', sans-serif; letter-spacing: 1px; font-style: italic;"""
        booleanParam (description: 'Run all implementations', name: 'DEPLOY_ALL' , defaultValue: true)
    }
    //environment { add env variables}
    stages {
        stage("Clean Checkout") {
            steps {
                echo "Sending Build notification"
                cleanWs()
                checkout scm
            }
        }
        stage("Dynamic Destroy") {
            when {
                allOf {
                    expression { params.TERRAGRUNT_DESTROY == true }
                    expression { params.IMPLEMENTATION_TO_DESTROY != '' }
                }
            }
            steps {
                script {
                    if (env.BRANCH_NAME == 'feature/sandbox') {
                        stage("Destroy Resources for Feature in SBX") {
                            withCredentials([string(credentialsId: '<>', variable: 'SBX_ARM_CLIENT_SECRET')]) {
                                // Run destroy in SBX
                                    sh "chmod +x ./login_and_grunt.sh"
                                    sh """#!/bin/bash
                                    set -x
                                    ./login_and_grunt.sh sbx destroy \${IMPLEMENTATION_TO_DESTROY}
                                    """
                            }
                        }
                    }
                    if (env.BRANCH_NAME == 'develop') {
                        stage("Destroy Resources DEV") {
                            withCredentials([string(credentialsId: '<>', variable: 'DEV_ARM_CLIENT_SECRET')]) {
                                // Run destroy DEV
                                sh "chmod +x ./login_and_grunt.sh"
                                sh """#!/bin/bash
                                set -x
                                ./login_and_grunt.sh dev destroy \${IMPLEMENTATION_TO_DESTROY}
                                """
                            }
                        }
                    }
                    if (env.BRANCH_NAME.startsWith('release/next')) {
                        stage("Deploy Resources in TST") {
                            withCredentials([string(credentialsId: '<>', variable: 'TST_ARM_CLIENT_SECRET')]) {
                                // Run destroy in TST
                                sh "chmod +x ./login_and_grunt.sh"
                                sh """#!/bin/bash
                                set -x
                                ./login_and_grunt.sh tst destroy \${IMPLEMENTATION_TO_DESTROY}
                                """
                            }
                        }
                    }
                    if (env.BRANCH_NAME == 'main') {
                        stage("Destroy Resources in PRD") {
                            withCredentials([string(credentialsId: '<>', variable: 'PRD_ARM_CLIENT_SECRET')]) {
                                // Run destroy in PRD
                                sh "chmod +x ./login_and_grunt.sh"
                                sh """#!/bin/bash
                                set -x
                                ./login_and_grunt.sh prd destroy \${IMPLEMENTATION_TO_DESTROY}
                                """
                            }
                        }
                    }
                }
            }
        }
        stage('Pre Build Checks ->') {
            steps {
                script {
                    // Install specific version of terraform, will use .terraform-version file for specific version
                    stage('Install TFenv') {
                        sh """#!/bin/bash
                        set -x
                        tfenv install
                        """
                    }
                    // Perform Terraform Lint
                    stage('IaC Linting') {
                        sh """#!/bin/bash
                        set -x
                        terraform fmt --recursive
                        """
                    }

                }
            }
        }
        stage('Pre Scan and Tests ->'){
            steps {
                script {
                    stage("Run IaC Tests") {
                        try {
                            sh """#!/bin/bash
                            set -x
                            # Run terratest here. We should look at detecting changes here and running only those possibly. 
                        """
                        } catch(err) {
                            step([$class: 'JUnitResultArchiver', testResults: '--junit-xml=${TESTRESULTPATH}/TEST-*.xml'])
                            if (currentBuild.result == 'UNSTABLE')
                                currentBuild.result = 'FAILURE'
                            throw err
                        }
                    }
                }
            }
        }
        stage('Dynamic Build & Deploy ->') {
            steps {
                script {
                    // feature branch 
                    if (env.BRANCH_NAME.startsWith('feature') && env.BRANCH_NAME != 'feature/sandbox') {
                        stage("Plan against SBX") {
                            withCredentials([string(credentialsId: '<>', variable: 'SBX_ARM_CLIENT_SECRET')]) {
                                // Run a plan to SBX
                                sh """#!/bin/bash
                                set -x
                                export ARM_CLIENT_SECRET=\${SBX_ARM_CLIENT_SECRET}
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh sbx plan\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                    // feature branch sandbox
                    if (env.BRANCH_NAME == 'feature/sandbox') {
                        stage("Deploy SBX") {
                            withCredentials([string(credentialsId: '<>', variable: 'SBX_ARM_CLIENT_SECRET')]) {
                                // Run a plan & apply to SBX
                                sh """#!/bin/bash
                                set -x
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh sbx apply\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                    // develop branch and PR
                    if (env.BRANCH_NAME.startsWith('PR-') && env.CHANGE_TARGET == 'develop') {
                        stage("Validate against Dev") {
                            withCredentials([string(credentialsId: '<>', variable: 'DEV_ARM_CLIENT_SECRET')]) {
                                // Run a plan on PR against Dev
                                sh """#!/bin/bash
                                set -x
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh dev plan\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                    if (env.BRANCH_NAME == 'develop') {
                        stage("Deploy Dev") {
                            withCredentials([string(credentialsId: '<>', variable: 'DEV_ARM_CLIENT_SECRET')]) {
                                // Run a plan & apply to DEV
                                sh """#!/bin/bash
                                set -x
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh dev apply\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                    // release/next branch and PR
                    if (env.BRANCH_NAME.startsWith('PR-') && env.CHANGE_TARGET == 'release/next') {
                        stage("Validate against TST") {
                            withCredentials([string(credentialsId: 'ar-ai-services-devsecops-tst', variable: 'TST_ARM_CLIENT_SECRET')]) {
                                // Run a plan on PR against TST
                                sh """#!/bin/bash
                                set -x
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh tst plan\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                    if (env.BRANCH_NAME.startsWith('release/next')) {
                        stage("Deploy TST") {
                            withCredentials([string(credentialsId: '<>', variable: 'TST_ARM_CLIENT_SECRET')]) {
                                // Run a plan & apply to TST
                                sh """#!/bin/bash
                                set -x
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh tst apply\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                    // main branch and PR
                    if (env.BRANCH_NAME.startsWith('PR-') && env.CHANGE_TARGET == 'main') {
                        stage("Validate against PRD") {
                            withCredentials([string(credentialsId: '<>', variable: 'PRD_ARM_CLIENT_SECRET')]) {
                                // Run a plan on PR against PRD
                                sh """#!/bin/bash
                                set -x
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh prd apply\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                    if (env.BRANCH_NAME == 'main') {
                        stage("Deploy PRD") {
                            withCredentials([string(credentialsId: '<>', variable: 'PRD_ARM_CLIENT_SECRET')]) {
                                // Run a plan & apply to PRD
                                sh """#!/bin/bash
                                set -x
                                if [[ \${DEPLOY_ALL} == "true" ]]; then RUN_ALL='-all'; fi
                                ./login_and_grunt.sh prd apply\${RUN_ALL} \${IMPLEMENTATION_FOLDER_TO_DEPLOY} \${IMPLEMENTATION_TO_DEPLOY}
                                """
                            }
                        }
                    }
                }
            }
        }
        stage('Post Build & Deploy Test ->'){
            steps {
                script {
                    stage('Run Integration Tests') {
                        sh """#!/bin/bash
                        set -euo pipefail
                        # Need to discuss what we want to run here
                        # Something that checks that services are up
                        """
                    }
                    stage('Report Test Results') {
                        sh """#!/bin/bash
                        set -euo pipefail
                        echo "Stubbed for now until we figure out post deploy tests"
                        """
                        //junit "**/reports/junit/*.xml"
                    }
                }
            }
        }
    }
    post {
        always {
            cleanWs(
                cleanWhenAborted : true,
                cleanWhenFailure : true,
                cleanWhenNotBuilt : false,
                cleanWhenSuccess : true,
                cleanWhenUnstable : true,
                skipWhenFailed : false,
                deleteDirs: true,
                notFailBuild : true,
                disableDeferredWipeout: true,
                patterns: [[pattern: '.git', type: 'INCLUDE'],
                            [pattern: 'impl', type: 'INCLUDE'],
                            [pattern: 'modules', type: 'INCLUDE'],
                            [pattern: 'build_cache/**', type: 'INCLUDE']])
        }
    }
}