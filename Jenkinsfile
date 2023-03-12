pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo 'Building..'
                // Get code from a GitHub repository
                git url: 'https://github.com/MIST3R420/hitc', branch: 'main', credentialsId: 'git-user-0'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing..'
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