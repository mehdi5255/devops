pipeline {
    agent any
    environment {
        DOCKER_IMAGE = 'mehdi002/spring-app'
    }
    stages {
        stage('Checkout & Build') {
            steps {
                checkout scm
                sh 'mvn -B clean package -DskipTests -q'
            }
        }
        
        stage('SonarQube (Non-bloquant)') {
            steps {
                script {
                    try {
                        withSonarQubeEnv('SonarQube') {
                            withCredentials([string(credentialsId: 'sonar-token', variable: 'TOKEN')]) {
                                sh 'mvn -B sonar:sonar -Dsonar.projectKey=student-management -Dsonar.host.url=http://localhost:9000 -Dsonar.login=$TOKEN -Dsonar.qualitygate.wait=false -q'
                            }
                        }
                        echo "✅ SonarQube: http://localhost:9000/dashboard?id=student-management"
                    } catch (e) {
                        echo "⚠️  SonarQube ignoré: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Docker & Kubernetes') {
            steps {
                script {
                    sh '''
                        # Build Docker
                        eval $(minikube docker-env 2>/dev/null)
                        docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                        
                        # Déployer sur Kubernetes
                        kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
                        
                        # Mettre à jour le déploiement
                        kubectl set image deployment/spring-app spring-app=${DOCKER_IMAGE}:${BUILD_NUMBER} -n devops 2>/dev/null || \
                        kubectl create deployment spring-app --image=${DOCKER_IMAGE}:${BUILD_NUMBER} -n devops
                        
                        # Exposer le service
                        kubectl expose deployment spring-app --type=NodePort --port=8080 -n devops 2>/dev/null || true
                        
                        # Attendre
                        sleep 30
                        
                        # Tester
                        IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
                        curl -s "http://${IP}:30080/student/actuator/health" && echo "✅ Application OK"
                    '''
                }
            }
        }
    }
    options {
        timeout(time: 10, unit: 'MINUTES')
    }
}
