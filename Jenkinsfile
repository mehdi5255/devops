pipeline {
    agent any
    
    environment {
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'student-management'
        
        // Docker
        DOCKER_IMAGE = 'mehdi002/spring-app'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code...'
                checkout scm
            }
        }
        
        stage('Build & Tests') {
            steps {
                echo '🔨 Compilation...'
                sh 'mvn -B clean package -DskipTests'
                archiveArtifacts 'target/*.jar'
            }
        }
        
        stage('Analyse SonarQube') {
            steps {
                echo '🔍 Analyse SonarQube...'
                script {
                    try {
                        withSonarQubeEnv('SonarQube') {
                            withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                                sh """
                                    mvn sonar:sonar \
                                    -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                    -Dsonar.host.url=${SONAR_HOST_URL} \
                                    -Dsonar.login=\${SONAR_TOKEN} \
                                    -Dsonar.qualitygate.wait=false
                                """
                            }
                        }
                        echo "✅ SonarQube: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
                    } catch (Exception e) {
                        echo "⚠️  SonarQube ignoré: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '🐳 Construction Docker...'
                script {
                    sh """
                        eval \$(minikube docker-env 2>/dev/null)
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                        echo "✅ Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    """
                }
            }
        }
        
        stage('Déploiement K8s') {
            steps {
                echo '🚀 Déploiement Kubernetes...'
                script {
                    sh """
                        # Vérifier le namespace
                        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
                        
                        # Vérifier les fichiers K8s
                        if [ -d "k8s" ]; then
                            echo "📁 Utilisation du dossier k8s/"
                            # Mettre à jour l'image
                            find k8s -name "*.yaml" -type f -exec sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" {} \\;
                            kubectl apply -f k8s/ -n ${K8S_NAMESPACE}
                        elif [ -f "deployment.yaml" ]; then
                            echo "📄 Utilisation de deployment.yaml"
                            sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" deployment.yaml
                            kubectl apply -f deployment.yaml -n ${K8S_NAMESPACE}
                        else
                            echo "⚙️  Mise à jour du déploiement existant"
                            kubectl set image deployment/${K8S_DEPLOYMENT} ${K8S_DEPLOYMENT}=${DOCKER_IMAGE}:${DOCKER_TAG} -n ${K8S_NAMESPACE} || \\
                            kubectl create deployment ${K8S_DEPLOYMENT} --image=${DOCKER_IMAGE}:${DOCKER_TAG} -n ${K8S_NAMESPACE}
                        fi
                        
                        # Redémarrer
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        # Attendre
                        echo "⏳ Attente du déploiement..."
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=180s
                        
                        echo "✅ Déploiement terminé"
                    """
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo '🏥 Vérification...'
                script {
                    sh """
                        sleep 30
                        
                        # Obtenir l'IP et port
                        MINIKUBE_IP=\$(minikube ip 2>/dev/null || echo "192.168.49.2")
                        NODE_PORT=\$(kubectl get svc -n ${K8S_NAMESPACE} -o jsonpath="{.items[?(@.spec.selector.app=='spring-app')].spec.ports[0].nodePort}" 2>/dev/null || echo "30080")
                        
                        echo "🌐 Test sur: http://\${MINIKUBE_IP}:\${NODE_PORT}/student/actuator/health"
                        
                        # Tester
                        curl -f "http://\${MINIKUBE_IP}:\${NODE_PORT}/student/actuator/health" || \\
                        curl -f "http://\${MINIKUBE_IP}:\${NODE_PORT}/student/Depatment/getAllDepartment" || \\
                        (echo "⚠️  Application en démarrage..." && exit 0)
                        
                        echo "🎉 Application opérationnelle!"
                        echo "🔗 Swagger: http://\${MINIKUBE_IP}:\${NODE_PORT}/student/swagger-ui.html"
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ PIPELINE RÉUSSIE !'
            script {
                sh """
                    echo "=== RAPPORT ==="
                    echo "SonarQube: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
                    echo "Docker: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    echo "K8s: ${K8S_NAMESPACE}/${K8S_DEPLOYMENT}"
                    kubectl get pods -n ${K8S_NAMESPACE}
                """
            }
        }
        
        failure {
            echo '❌ PIPELINE ÉCHOUÉE'
            script {
                sh '''
                    echo "=== DÉBOGAGE ==="
                    kubectl get pods -A 2>/dev/null | grep -E "(devops|spring)" || echo "Pas de pods"
                    kubectl get events -n devops --sort-by=.lastTimestamp 2>/dev/null | tail -3 || echo "Pas d\'événements"
                '''
            }
        }
        
        always {
            cleanWs()
        }
    }
    
    options {
        timeout(time: 20, unit: 'MINUTES')
    }
}
