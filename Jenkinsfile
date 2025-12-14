pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'mehdi002/spring-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        
        stage('SonarQube') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh 'mvn sonar:sonar -Dsonar.projectKey=student-management -Dsonar.host.url=http://localhost:9000 -Dsonar.login=${SONAR_TOKEN}'
                }
            }
        }
        
        stage('Docker Build') {
            steps {
                sh '''
                    eval $(minikube docker-env)
                    docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                '''
            }
        }
        
        stage('Kubernetes Deploy') {
            steps {
                sh '''
                    kubectl set image deployment/spring-app spring-app=${DOCKER_IMAGE}:${DOCKER_TAG} -n devops
                    kubectl rollout restart deployment/spring-app -n devops
                    kubectl rollout status deployment/spring-app -n devops --timeout=300s
                '''
            }
        }
        
        stage('Test') {
            steps {
                sleep 30
                sh 'curl -f http://192.168.49.2:30080/student/Depatment/getAllDepartment'
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline réussie!'
        }
        failure {
            echo '❌ Pipeline échouée'
        }
    }
}
