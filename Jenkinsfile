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
                        call npm ci --prefer-binary

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

        stage('Deploy') {
            steps {
                script {

                    // Application ports
                    def appPort = (params.DEPLOY_ENV == 'staging') ? '3002' : '3001'

                    // Nginx ports
                    def nginxPort = (params.DEPLOY_ENV == 'staging') ? '8096' : '8095'

                    echo "=========================================="
                    echo "Deployment Configuration"
                    echo "Environment : ${params.DEPLOY_ENV}"
                    echo "Application : ${appPort}"
                    echo "Nginx       : ${nginxPort}"
                    echo "=========================================="

                    // Find generated package tarball
                    def pkgFile = bat(
                        script: '@powershell -NoProfile -Command "(Get-Item *.tgz | Select-Object -First 1).Name"',
                        returnStdout: true
                    ).trim()

                    echo "Package: ${pkgFile}"

                    // Prevent Jenkins from killing the deployed Node process
                    withEnv([
                        'JENKINS_NODE_COOKIE=dontKillMe',
                        'BUILD_ID=dontKillMe',
                        'PATH+NODE=C:/nvm4w/nodejs',
                        'PYTHON=C:/Program Files/Python313/python.exe',
                        'npm_config_python=C:/Program Files/Python313/python.exe'
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

