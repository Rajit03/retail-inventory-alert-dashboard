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
        choice(name: 'DEPLOY_ENV', choices: ['dev', 'staging'], description: 'Target deployment environment')
        string(name: 'DEPLOY_ROOT', defaultValue: 'C:\\deploy\\retail-inventory', description: 'Deployment root directory')
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
                    echo ==========================================
                '''
            }
        }

        stage('Build') {
            steps {
                bat '''
                    call node -v
                    call npm -v
                    call npm ci
                    call npm run build
                    call npm test
                '''
            }
        }

        stage('Package') {
            steps {
                bat '''
                    if exist *.tgz del /f /q *.tgz
                    call npm pack
                '''
                archiveArtifacts artifacts: '*.tgz, build-info.json', fingerprint: true
            }
        }

        stage('Deploy') {
            steps {
                script {
                    def appPort = (params.DEPLOY_ENV == 'staging') ? '3002' : '3001'
                    def nginxPort = (params.DEPLOY_ENV == 'staging') ? '8082' : '8081'

                    // Find the generated package tarball
                    def pkgFile = bat(script: '@powershell -NoProfile -Command "(Get-Item *.tgz | Select-Object -First 1).Name"', returnStdout: true).trim()

                    withEnv(['JENKINS_NODE_COOKIE=dontKillMe', 'BUILD_ID=dontKillMe']) {
                        bat "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\deploy.ps1 -Environment ${params.DEPLOY_ENV} -Port ${appPort} -DeployRoot \"${params.DEPLOY_ROOT}\" -PackagePath \"${pkgFile}\" -BuildNumber ${BUILD_NUMBER}"
                    }

                    bat "powershell -NoProfile -Command \"try { (Invoke-WebRequest -UseBasicParsing http://localhost:${nginxPort}/health).Content } catch { Write-Output 'Nginx not reachable on ${nginxPort} (start Nginx)'; exit 0 }\""

                    echo "Application URL: http://localhost:${nginxPort}/items"
                }
            }
        }
    }

    post {
        success {
            script {
                def nginxPort = (params.DEPLOY_ENV == 'staging') ? '8082' : '8081'
                echo "Deployment successful! Environment: ${params.DEPLOY_ENV}, Build: #${BUILD_NUMBER}, URL: http://localhost:${nginxPort}/items"
            }
        }
        failure {
            echo "Pipeline failed"
        }
        always {
            archiveArtifacts allowEmptyArchive: true, artifacts: 'build-info.json'
        }
    }
}
