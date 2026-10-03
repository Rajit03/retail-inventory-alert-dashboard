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
                    @echo off

                    echo ==========================================
                    echo Node and npm versions
                    echo ==========================================
                    call node -v
                    call npm -v

                    echo ==========================================
                    echo Cleaning dependencies
                    echo ==========================================
                    if exist node_modules (
                        rmdir /s /q node_modules
                    )

                    echo ==========================================
                    echo Installing dependencies
                    echo ==========================================
                    call npm ci --prefer-binary
                    if errorlevel 1 exit /b 1

                    echo ==========================================
                    echo Checking better-sqlite3
                    echo ==========================================
                    call npm ls better-sqlite3
                    if errorlevel 1 exit /b 1

                    echo ==========================================
                    echo Checking Express
                    echo ==========================================
                    call npm ls express
                    if errorlevel 1 exit /b 1

                    echo ==========================================
                    echo Build
                    echo ==========================================
                    call npm run build
                    if errorlevel 1 exit /b 1

                    echo ==========================================
                    echo Tests
                    echo ==========================================
                    call npm test
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Package') {
            steps {
                bat '''
                    @echo off
                    if exist *.tgz del /f /q *.tgz
                    call npm pack
                    if errorlevel 1 exit /b 1
                '''

                archiveArtifacts artifacts: '*.tgz, build-info.json',
                                 fingerprint: true
            }
        }

        stage('Deploy') {
            steps {
                script {

                    def appPort = (params.DEPLOY_ENV == 'staging') ? '3002' : '3001'
                    def nginxPort = (params.DEPLOY_ENV == 'staging') ? '8096' : '8095'

                    echo "=========================================="
                    echo "Deployment Configuration"
                    echo "Environment : ${params.DEPLOY_ENV}"
                    echo "Application : ${appPort}"
                    echo "Nginx       : ${nginxPort}"
                    echo "=========================================="

                    def pkgFile = bat(
                        script: '@powershell -NoProfile -Command "(Get-Item *.tgz | Select-Object -First 1).Name"',
                        returnStdout: true
                    ).trim()

                    echo "Package: ${pkgFile}"

                    withEnv([
                        'JENKINS_NODE_COOKIE=dontKillMe',
                        'BUILD_ID=dontKillMe'
                    ]) {

                        bat """
                            powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\deploy.ps1 ^
                            -Environment ${params.DEPLOY_ENV} ^
                            -Port ${appPort} ^
                            -DeployRoot "${params.DEPLOY_ROOT}" ^
                            -PackagePath "${pkgFile}" ^
                            -BuildNumber ${BUILD_NUMBER}
                        """
                    }

                    echo "Checking application directly..."

                    bat """
                        powershell -NoProfile -Command ^
                        "try { ^
                            (Invoke-WebRequest -UseBasicParsing http://localhost:${appPort}/health).Content ^
                        } catch { ^
                            Write-Output 'Application health check failed on port ${appPort}'; ^
                            exit 1 ^
                        }"
                    """

                    echo "Checking Nginx..."

                    bat """
                        powershell -NoProfile -Command ^
                        "try { ^
                            (Invoke-WebRequest -UseBasicParsing http://localhost:${nginxPort}/health).Content ^
                        } catch { ^
                            Write-Output 'Nginx not reachable on port ${nginxPort}. Make sure Nginx is running.'; ^
                            exit 1 ^
                        }"
                    """

                    echo "Application URL: http://localhost:${nginxPort}/items"
                }
            }
        }
    }

    post {

        success {
            script {

                def nginxPort =
                    (params.DEPLOY_ENV == 'staging') ? '8096' : '8095'

                echo "=========================================="
                echo "Deployment successful!"
                echo "Environment : ${params.DEPLOY_ENV}"
                echo "Build       : #${BUILD_NUMBER}"
                echo "Application : http://localhost:${nginxPort}/items"
                echo "=========================================="
            }
        }

        failure {
            echo "Pipeline failed"
        }

        always {
            archiveArtifacts(
                allowEmptyArchive: true,
                artifacts: 'build-info.json'
            )
        }
    }
}