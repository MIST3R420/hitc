pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo 'Building..'
                // Get code from a GitHub repository
                git url: 'https://github.com/MIST3R420/hitc', branch: 'main', credentialsId: 'git-user-0'
                sh "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
                sh "chmod 700 get_helm.sh"
                sh "./get_helm.sh --no-sudo"
            }
        }
        stage('Test') {
            steps {
                echo 'Testing..'
                sh "chmod 755 bin/*.sh"
                sh "./bin/common.sh deploy_strimzi"
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying....'
            }
        }
    }
}