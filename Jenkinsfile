pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build & Skip Tests') {
            steps {
                sh '''
                    mvn clean compile -DskipTests
                    mvn package -DskipTests
                '''
            }
        }
        
        stage('SonarQube') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn sonar:sonar \
                              -Dsonar.projectKey=student-management \
                              -Dsonar.host.url=http://localhost:9000 \
                              -Dsonar.login=${SONAR_TOKEN} \
                              -Dsonar.skipTests=true
                        """
                    }
                }
            }
        }
        
        stage('Docker Build') {
            steps {
                sh '''
                    docker build -t mehdi002/spring-app:${BUILD_NUMBER} .
                    docker images | grep mehdi002
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline terminée'
        }
    }
}
