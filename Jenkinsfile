pipeline {
    agent any
    
    environment {
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'student-management'
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
        
        // Docker
        DOCKER_IMAGE = 'mehdi002/spring-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // Application
        APP_URL = 'http://192.168.49.2:30080'
        CONTEXT_PATH = '/student'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code source depuis master...'
                checkout([$class: 'GitSCM', 
                         branches: [[name: '*/master']], 
                         extensions: [], 
                         userRemoteConfigs: [[url: 'https://github.com/mehdi5255/devops.git']]])
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
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
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
                echo '⚡ Attente du résultat Quality Gate...'
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '🐳 Construction de l\'image Docker...'
                script {
                    sh '''
                        eval $(minikube docker-env 2>/dev/null) || echo "Environnement Minikube Docker"
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        echo "✅ Image construite: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    '''
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Déploiement sur Kubernetes...'
                script {
                    sh """
                        echo "Vérification de l'accès Kubernetes..."
                        kubectl get nodes
                        
                        echo "Mise à jour du déploiement..."
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            spring-app=${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -n ${K8S_NAMESPACE}
                        
                        echo "Redémarrage du déploiement..."
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE}
                        
                        echo "Attente du déploiement..."
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE} --timeout=300s
                        
                        echo "✅ Déploiement Kubernetes terminé !"
                    """
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo '🏥 Vérification de la santé de l\'application...'
                script {
                    sleep 40
                    
                    sh """
                        echo "Test 1: API Department..."
                        curl -f ${APP_URL}${CONTEXT_PATH}/Depatment/getAllDepartment || exit 1
                        
                        echo -e "\n✅ Tous les tests passent !"
                        echo "Application disponible sur: ${APP_URL}${CONTEXT_PATH}/swagger-ui.html"
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo '✅✅✅ PIPELINE RÉUSSIE ! ✅✅✅'
            script {
                sh '''
                    echo "=============================================="
                    echo "🎉 DÉPLOIEMENT COMPLET RÉUSSI !"
                    echo "=============================================="
                    echo ""
                    echo "📊 RÉSUMÉ :"
                    echo "• Application: ${APP_URL}${CONTEXT_PATH}/swagger-ui.html"
                    echo "• Image Docker: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    echo "• Namespace: ${K8S_NAMESPACE}"
                    echo "• Build: #${BUILD_NUMBER}"
                    echo ""
                    echo "📦 État Kubernetes:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                    echo ""
                    echo "=============================================="
                '''
            }
        }
        
        failure {
            echo '❌❌❌ PIPELINE ÉCHOUÉE ❌❌❌'
            script {
                sh '''
                    echo "🔧 DÉBOGAGE :"
                    echo "1. État des pods:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                    echo ""
                    echo "2. Logs Spring Boot:"
                    kubectl logs -l app=spring-app -n ${K8S_NAMESPACE} --tail=30 2>/dev/null || echo "Pas de logs"
                    echo ""
                    echo "3. État Minikube:"
                    minikube status 2>/dev/null || echo "Minikube non disponible"
                '''
            }
        }
        
        always {
            echo '🏁 Pipeline terminée.'
            sh '''
                echo "Durée: ${currentBuild.durationString}"
                echo "Workspace: ${WORKSPACE}"
            '''
        }
    }
    
    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
}
