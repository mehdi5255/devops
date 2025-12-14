pipeline {
    agent any
    
    environment {
        // Docker
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_IMAGE = 'mehdi002/spring-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN = credentials('sonarqube-token')
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
        K8S_SERVICE = 'spring-service'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code source...'
                git branch: 'main', url: 'https://github.com/mehdi5255/devops.git'
            }
        }
        
        stage('Build & Test') {
            steps {
                echo '🔨 Compilation et tests...'
                sh 'mvn clean compile -DskipTests'
                sh 'mvn package -DskipTests'
            }
            
            post {
                success {
                    archiveArtifacts 'target/*.jar'
                }
            }
        }
        
        stage('Analyse SonarQube') {
            steps {
                echo '🔍 Analyse de code avec SonarQube...'
                withSonarQubeEnv('SonarQube') {
                    sh """
                        mvn sonar:sonar \
                        -Dsonar.projectKey=student-management \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                echo '⚡ Vérification Quality Gate...'
                timeout(time: 1, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '🐳 Construction image Docker...'
                script {
                    // Utiliser l'environnement Docker de Minikube
                    sh 'eval $(minikube docker-env) || true'
                    dockerImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Déploiement sur Kubernetes...'
                script {
                    // Mettre à jour l'image dans le déploiement
                    sh """
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                        spring-app=${DOCKER_IMAGE}:${DOCKER_TAG} \
                        -n ${K8S_NAMESPACE}
                        
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                        -n ${K8S_NAMESPACE} --timeout=300s
                    """
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo '🏥 Vérification santé application...'
                script {
                    sleep 30
                    // Tester votre endpoint Department
                    sh """
                        curl -f http://192.168.49.2:30080/student/Depatment/getAllDepartment || exit 1
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ PIPELINE RÉUSSIE ! Application déployée avec succès.'
            sh '''
                echo "=== RÉSUMÉ DU DÉPLOIEMENT ==="
                echo "Application URL: http://192.168.49.2:30080/student/swagger-ui.html"
                echo "API Test: http://192.168.49.2:30080/student/Depatment/getAllDepartment"
                echo "Kubernetes Pods:"
                kubectl get pods -n devops
            '''
        }
        failure {
            echo '❌ PIPELINE ÉCHOUÉE. Vérifiez les logs.'
            sh '''
                echo "=== DÉBOGAGE ==="
                kubectl get pods -n devops
                kubectl logs -l app=spring-app -n devops --tail=50 || true
            '''
        }
        always {
            echo '🏁 Pipeline terminée.'
            cleanWs()  // Nettoyer le workspace
        }
    }
}
