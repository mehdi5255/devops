pipeline {
    agent any
    
    environment {
        // SonarQube - utiliser directement le token
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'student-management'
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
        
        // Docker
        DOCKER_IMAGE = 'mehdi002/spring-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code source...'
                checkout scm
            }
        }
        
        stage('Build & Test') {
            steps {
                echo '🔨 Compilation et tests...'
                sh '''
                    mvn clean compile -DskipTests
                    mvn package -DskipTests
                '''
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
                    // Utiliser le token depuis les credentials
                    withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn sonar:sonar \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.host.url=${SONAR_HOST_URL} \
                            -Dsonar.login=${SONAR_TOKEN}
                        """
                    }
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
                    // Activer Minikube Docker
                    sh 'eval $(minikube docker-env 2>/dev/null) || echo "Minikube Docker déjà activé"'
                    sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Déploiement sur Kubernetes...'
                script {
                    // Tester l'accès Kubernetes d'abord
                    sh '''
                        kubectl get nodes
                        kubectl get pods -n devops
                    '''
                    
                    // Déployer
                    sh """
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                        spring-app=${DOCKER_IMAGE}:${DOCKER_TAG} \
                        -n ${K8S_NAMESPACE}
                        
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} \
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
                    sh '''
                        # Tester l'API
                        curl -f http://192.168.49.2:30080/student/Depatment/getAllDepartment || exit 1
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ PIPELINE RÉUSSIE !'
            script {
                echo "=== RÉSUMÉ ==="
                sh '''
                    echo "Application: http://192.168.49.2:30080/student/swagger-ui.html"
                    echo "Kubernetes Pods:"
                    kubectl get pods -n devops
                    echo "Services:"
                    kubectl get svc -n devops
                '''
            }
        }
        failure {
            echo '❌ PIPELINE ÉCHOUÉE.'
            script {
                echo "=== DÉBOGAGE ==="
                sh '''
                    echo "1. État Kubernetes:"
                    kubectl get pods -n devops
                    echo ""
                    echo "2. Logs Spring Boot:"
                    kubectl logs -l app=spring-app -n devops --tail=30 2>/dev/null || echo "Pas de logs disponibles"
                    echo ""
                    echo "3. État Minikube:"
                    minikube status 2>/dev/null || echo "Minikube non disponible"
                '''
            }
        }
        always {
            echo '🏁 Pipeline terminée.'
            // cleanWs() est optionnel - décommenter si nécessaire
            // cleanWs()
        }
    }
}
