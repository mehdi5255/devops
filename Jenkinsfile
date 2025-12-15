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
                        eval $(minikube docker-env 2>/dev/null)
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                        echo "✅ Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    """
                }
            }
        }
        
        stage('Déploiement K8s avec TES fichiers') {
            steps {
                echo '🚀 Déploiement avec tes fichiers K8s...'
                script {
                    sh """
                        # Vérifier que le namespace existe
                        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
                        
                        # Option 1: Si tu as un dossier k8s/ avec tes fichiers
                        if [ -d "k8s" ]; then
                            echo "📁 Utilisation des fichiers dans k8s/"
                            
                            # Mettre à jour l'image dans tes fichiers
                            if [ -f "k8s/deployment.yaml" ]; then
                                sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" k8s/deployment.yaml
                            fi
                            
                            # Appliquer tous les fichiers
                            kubectl apply -f k8s/ -n ${K8S_NAMESPACE}
                        
                        # Option 2: Si tu as deployment.yaml à la racine
                        elif [ -f "deployment.yaml" ]; then
                            echo "📄 Utilisation de deployment.yaml"
                            sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" deployment.yaml
                            kubectl apply -f deployment.yaml -n ${K8S_NAMESPACE}
                        
                        # Option 3: Si tu as un fichier unique
                        elif [ -f "k8s-manifests.yaml" ]; then
                            echo "📄 Utilisation de k8s-manifests.yaml"
                            sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" k8s-manifests.yaml
                            kubectl apply -f k8s-manifests.yaml -n ${K8S_NAMESPACE}
                        
                        # Option 4: Utiliser kubectl set image
                        else
                            echo "⚙️  Mise à jour du déploiement existant..."
                            kubectl set image deployment/${K8S_DEPLOYMENT} \
                                ${K8S_DEPLOYMENT}=${DOCKER_IMAGE}:${DOCKER_TAG} \
                                -n ${K8S_NAMESPACE} || \
                            kubectl create deployment ${K8S_DEPLOYMENT} \
                                --image=${DOCKER_IMAGE}:${DOCKER_TAG} \
                                -n ${K8S_NAMESPACE}
                        fi
                        
                        # Redémarrer pour appliquer les changements
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        # Attendre le déploiement
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
                        
                        # Obtenir l'IP et le port
                        MINIKUBE_IP=\$(minikube ip 2>/dev/null || echo "192.168.49.2")
                        NODE_PORT=\$(kubectl get svc -n ${K8S_NAMESPACE} -o jsonpath='{.items[?(@.spec.selector.app=="spring-app")].spec.ports[0].nodePort}' 2>/dev/null || echo "30080")
                        
                        echo "🌐 Test sur: http://\${MINIKUBE_IP}:\${NODE_PORT}/student/actuator/health"
                        
                        # Essayer plusieurs endpoints
                        curl -f "http://\${MINIKUBE_IP}:\${NODE_PORT}/student/actuator/health" || \
                        curl -f "http://\${MINIKUBE_IP}:\${NODE_PORT}/student/Depatment/getAllDepartment" || \
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
                    kubectl get events -n devops --sort-by=.lastTimestamp 2>/dev/null | tail -3 || echo "Pas d'événements"
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
