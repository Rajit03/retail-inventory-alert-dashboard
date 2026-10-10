pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    parameters {
        choice(
            name: 'DEPLOY_ENV',
            choices: ['dev', 'staging'],
            description: 'Target deployment environment'
        )

        string(
            name: 'DEPLOY_ROOT',
            defaultValue: 'C:\\deploy\\retail-inventory',
            description: 'Deployment root directory'
        )

        string(
            name: 'REGISTRY',
            defaultValue: 'localhost:5000',
            description: 'Local Docker Registry host and port'
        )

        booleanParam(
            name: 'RUN_ANSIBLE',
            defaultValue: true,
            description: 'Provision and deploy the release to the Ansible-managed WSL node'
        )
    }

    environment {
        IMAGE_NAME = 'retail-inventory-alert'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                bat '''
                    @echo off
                    echo ==========================================
                    echo Checkout Stage
                    echo Git Commit:
                    git rev-parse HEAD
                    echo Target Environment: %DEPLOY_ENV%
                    echo Deploy Root: %DEPLOY_ROOT%
                    echo Registry: %REGISTRY%
                    echo Run Ansible: %RUN_ANSIBLE%
                    echo ==========================================
                '''
            }
        }

        stage('Build') {
            steps {
                withEnv([
                    'PATH+NODE=C:/nvm4w/nodejs',
                    'PYTHON=C:/Program Files/Python313/python.exe',
                    'npm_config_python=C:/Program Files/Python313/python.exe'
                ]) {
                    bat '''
                        call node -v
                        call npm -v

                        echo ==========================================
                        echo Installing dependencies
                        echo ==========================================
                        call npm ci --prefer-binary --ignore-scripts

                        echo ==========================================
                        echo Checking Express installation
                        echo ==========================================
                        call npm ls express

                        echo ==========================================
                        echo Checking node_modules
                        echo ==========================================
                        if exist node_modules\\express (
                            echo Express module exists
                        ) else (
                            echo ERROR: Express module NOT FOUND
                            exit /b 1
                        )

                        echo ==========================================
                        echo Build
                        echo ==========================================
                        call npm run build

                        echo ==========================================
                        echo Tests
                        echo ==========================================
                        call npm test
                    '''
                }
            }
        }

        // Quality gate: failing UI tests fail this stage and stop downstream stages
        stage('UI Tests (Selenium)') {
            steps {
                withEnv([
                    'PATH+NODE=C:/nvm4w/nodejs',
                    'PATH+MAVEN=C:/DevTools/apache-maven-3.9.16/bin'
                ]) {
                    bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\run-selenium-ci.ps1'
                }
            }
            post {
                always {
                    junit allowEmptyResults: false,
                          testResults: 'tests/selenium/target/surefire-reports/*.xml'
                    archiveArtifacts allowEmptyArchive: true,
                                     artifacts: 'tests/selenium/target/screenshots/*.png, tests/selenium/target/site/surefire-report.html, tests/selenium/target/ci-app*.log'
                }
            }
        }

        stage('Package') {
            steps {
                withEnv(['PATH+NODE=C:/nvm4w/nodejs']) {
                    bat '''
                        if exist *.tgz del /f /q *.tgz
                        call npm pack
                    '''
                }

                archiveArtifacts artifacts: '*.tgz, build-info.json',
                                 fingerprint: true
            }
        }

        stage('Docker Build') {
            steps {
                withEnv(['PATH+NODE=C:/nvm4w/nodejs']) {
                    script {
                        def dockerCheck = bat(script: 'docker version', returnStatus: true)
                        if (dockerCheck != 0) {
                            echo "ERROR: Docker daemon is unreachable or not running!"
                            error("Docker is unreachable or not running on the agent.")
                        }

                        def appVer = bat(
                            script: '@node -p "require(\'./package.json\').version"',
                            returnStdout: true
                        ).trim()

                        env.APP_VERSION = appVer
                        env.IMAGE_TAG = "${env.APP_VERSION}-${BUILD_NUMBER}"
                        env.IMAGE_REF = "${params.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"

                        def gitCommit = bat(
                            script: '@git rev-parse --short HEAD',
                            returnStdout: true
                        ).trim()

                        echo "=========================================="
                        echo "Docker Build"
                        echo "Version     : ${env.APP_VERSION}"
                        echo "Image Tag   : ${env.IMAGE_TAG}"
                        echo "Image Ref   : ${env.IMAGE_REF}"
                        echo "Git Commit  : ${gitCommit}"
                        echo "=========================================="

                        bat "docker build -t ${env.IMAGE_REF} -t ${params.REGISTRY}/${env.IMAGE_NAME}:latest --label build.number=${BUILD_NUMBER} --label git.commit=${gitCommit} ."
                        bat "docker image ls ${params.REGISTRY}/${env.IMAGE_NAME}"
                    }
                }
            }
        }

        stage('Docker Push') {
            steps {
                script {
                    echo "=========================================="
                    echo "Ensuring Docker Registry & Pushing Images"
                    echo "=========================================="

                    bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\ensure-registry.ps1'

                    bat "docker push ${env.IMAGE_REF}"
                    bat "docker push ${params.REGISTRY}/${env.IMAGE_NAME}:latest"

                    bat """
                        @echo off
                        echo Image Reference: ${env.IMAGE_REF} > docker-registry-evidence.txt
                        echo Latest Reference: ${params.REGISTRY}/${env.IMAGE_NAME}:latest >> docker-registry-evidence.txt
                        echo Date: %DATE% %TIME% >> docker-registry-evidence.txt
                        echo. >> docker-registry-evidence.txt
                        echo Registry Catalog: >> docker-registry-evidence.txt
                        curl.exe -s http://localhost:5000/v2/_catalog >> docker-registry-evidence.txt
                        echo. >> docker-registry-evidence.txt
                        echo Image Tags List: >> docker-registry-evidence.txt
                        curl.exe -s http://localhost:5000/v2/retail-inventory-alert/tags/list >> docker-registry-evidence.txt
                        type docker-registry-evidence.txt
                    """
                }
            }
        }

        stage('Deploy Container') {
            steps {
                script {
                    // Application ports
                    def appPort = (params.DEPLOY_ENV == 'staging') ? '3002' : '3001'

                    // Nginx ports
                    def nginxPort = (params.DEPLOY_ENV == 'staging') ? '8096' : '8095'

                    echo "=========================================="
                    echo "Deploying Container"
                    echo "Environment : ${params.DEPLOY_ENV}"
                    echo "Host Port   : ${appPort}"
                    echo "Nginx Port  : ${nginxPort}"
                    echo "Image Ref   : ${env.IMAGE_REF}"
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Deploy Root : ${params.DEPLOY_ROOT}"
                    echo "=========================================="

                    bat """
                        powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\deploy-container.ps1 ^
                        -Environment "${params.DEPLOY_ENV}" ^
                        -HostPort ${appPort} ^
                        -ImageRef "${env.IMAGE_REF}" ^
                        -BuildNumber "${BUILD_NUMBER}" ^
                        -DeployRoot "${params.DEPLOY_ROOT}"
                    """

                    echo "Application Direct URL: http://localhost:${appPort}/items"
                    echo "Nginx Reverse Proxy URL: http://localhost:${nginxPort}/items"
                }
            }
        }

        stage('Provision Node (Ansible)') {
            when {
                expression { return params.RUN_ANSIBLE }
            }
            steps {
                bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\node-ops.ps1 -Action provision -LogFile logs\\ansible-provision-%BUILD_NUMBER%.log'
            }
        }

        stage('Deploy Release (Ansible)') {
            when {
                expression { return params.RUN_ANSIBLE }
            }
            steps {
                script {
                    def pkgPath = bat(
                        script: '@powershell -NoProfile -Command "(Get-Item *.tgz | Select-Object -First 1).FullName"',
                        returnStdout: true
                    ).trim()

                    echo "Deploying release package to Ansible node: ${pkgPath}"

                    bat """
                        powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\node-ops.ps1 ^
                        -Action deploy ^
                        -ReleaseId b${BUILD_NUMBER} ^
                        -PackagePath "${pkgPath}" ^
                        -LogFile logs\\ansible-deploy-${BUILD_NUMBER}.log
                    """
                }
            }
        }

        stage('End-to-End Verification') {
            when {
                expression { return params.RUN_ANSIBLE }
            }
            steps {
                script {
                    def appPort = (params.DEPLOY_ENV == 'staging') ? '3002' : '3001'
                    def nginxPort = (params.DEPLOY_ENV == 'staging') ? '8096' : '8095'
                    def gitCommit = bat(
                        script: '@git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    bat "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\node-ops.ps1 -Action healthcheck -LogFile logs\\ansible-healthcheck-${BUILD_NUMBER}.log"

                    bat "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\e2e-verify.ps1 -Environment ${params.DEPLOY_ENV} -HostPort ${appPort} -NginxPort ${nginxPort} -ReleaseId b${BUILD_NUMBER} -ImageTag ${env.IMAGE_TAG} -GitCommit ${gitCommit} -BuildNumber ${BUILD_NUMBER}"
                }
            }
        }
    }

    post {

        success {
            script {
                def nginxPort = (params.DEPLOY_ENV == 'staging') ? '8096' : '8095'

                echo "=========================================="
                echo "Deployment & End-to-End Verification successful!"
                echo "Environment : ${params.DEPLOY_ENV}"
                echo "Build       : #${BUILD_NUMBER}"
                echo "Application : http://localhost:${nginxPort}/items"
                echo "Ansible Node: http://localhost:8300/items"
                echo "=========================================="
            }
        }

        failure {
            echo "Pipeline failed! See docs/troubleshooting-guide.md for diagnosis and remediation."
        }

        always {
            script {
                bat(
                    script: '''
                        @echo off
                        echo === DOCKER CONTAINERS (retail-inventory) === > docker-state.txt
                        docker ps -a --filter name=retail-inventory >> docker-state.txt 2>&1
                        echo. >> docker-state.txt
                        echo === DOCKER IMAGES (localhost:5000/retail-inventory-alert) === >> docker-state.txt
                        docker images localhost:5000/retail-inventory-alert >> docker-state.txt 2>&1
                    ''',
                    returnStatus: true
                )
            }

            archiveArtifacts(
                allowEmptyArchive: true,
                artifacts: '*.tgz, build-info.json, docker-registry-evidence.txt, docker-state.txt, e2e-verification.txt, logs/*.log'
            )
        }
    }
}
