pipeline {
    agent any
    
    environment {
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'student-management'
        
        // Docker
        DOCKER_HUB_CREDENTIALS = 'docker-hub-credentials' // À créer dans Jenkins
        DOCKER_IMAGE_NAME = 'mehdi002/spring-app' // Votre nom d'image
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
        
        // Application
        APP_URL = 'http://192.168.49.2:30080'
        CONTEXT_PATH = '/student'
        
        // Base de données (si nécessaire)
        DB_URL = 'jdbc:mysql://my-mysql:3306/studentdb?createDatabaseIfNotExist=true&allowPublicKeyRetrieval=true&useSSL=false&serverTimezone=UTC'
        DB_USERNAME = 'root'
        DB_PASSWORD = ''
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code depuis GitHub...'
                checkout([$class: 'GitSCM', 
                         branches: [[name: '*/master']], 
                         extensions: [], 
                         userRemoteConfigs: [[url: 'https://github.com/mehdi5255/devops.git']]])
            }
        }

        stage('Build sans tests') {
            steps {
                echo '🔨 Compilation avec Maven...'
                sh 'mvn -B clean install -DskipTests'
            }
            
            post {
                success {
                    archiveArtifacts 'target/*.jar'
                }
            }
        }

        stage('Analyse SonarQube') {
            steps {
                echo '🔍 Analyse SonarQube en cours...'
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn -B sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dsonar.token=${SONAR_TOKEN}
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                echo '⚡ Vérification du Quality Gate...'
                script {
                    timeout(time: 10, unit: 'MINUTES') {
                        def qg = waitForQualityGate(abortPipeline: true)
                        echo "✅ Quality Gate Status: ${qg.status}"
                    }
                }
            }
        }

        stage('Build Image Docker Locale') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                echo '🐳 Construction de l\'image Docker locale (pour Minikube)...'
                script {
                    sh '''
                        # Utiliser le registre Docker de Minikube
                        eval $(minikube docker-env 2>/dev/null) || echo "Environnement Minikube Docker"
                        
                        # Construire l'image
                        docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} .
                        
                        # Tagger aussi comme latest pour Minikube
                        docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} ${DOCKER_IMAGE_NAME}:latest
                        
                        echo "✅ Images construites:"
                        echo "   - ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                        echo "   - ${DOCKER_IMAGE_NAME}:latest"
                    '''
                }
            }
        }

        stage('Push vers Docker Hub (Optionnel)') {
            when {
                expression { 
                    (currentBuild.result == null || currentBuild.result == 'SUCCESS') &&
                    env.DOCKER_HUB_CREDENTIALS != 'your-credintials' 
                }
            }
            steps {
                echo '📦 Push vers Docker Hub...'
                script {
                    docker.withRegistry('https://index.docker.io/v1/', "${DOCKER_HUB_CREDENTIALS}") {
                        // Construire une nouvelle image pour Docker Hub
                        def dockerHubImage = docker.build("${DOCKER_IMAGE_NAME}:hub-${DOCKER_TAG}")
                        dockerHubImage.push()
                        dockerHubImage.push('latest')
                        echo "✅ Image poussée vers Docker Hub"
                    }
                }
            }
        }

        stage('Déploiement Kubernetes') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                echo '🚀 Déploiement sur Kubernetes...'
                script {
                    sh """
                        echo "Vérification de l'accès Kubernetes..."
                        kubectl get nodes
                        
                        echo "Mise à jour du déploiement avec la nouvelle image..."
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            spring-app=${DOCKER_IMAGE_NAME}:${DOCKER_TAG} \
                            -n ${K8S_NAMESPACE} || echo "Premier déploiement, continuons..."
                        
                        echo "Redémarrage du déploiement..."
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE}
                        
                        echo "Attente du déploiement (max 5min)..."
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE} --timeout=300s
                        
                        echo "✅ Déploiement Kubernetes terminé !"
                    """
                }
            }
        }

        stage('Health Check') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                echo '🏥 Vérification de la santé de l\'application...'
                script {
                    retry(3) {
                        sleep 30
                        sh """
                            echo "Test de l'API Department..."
                            curl -f ${APP_URL}${CONTEXT_PATH}/Depatment/getAllDepartment || exit 1
                            
                            echo -e "\n✅ L'application répond correctement !"
                            echo "📊 Application disponible sur: ${APP_URL}${CONTEXT_PATH}/swagger-ui.html"
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅✅✅ PIPELINE RÉUSSIE ! ✅✅✅'
            script {
                sh """
                    echo "=============================================="
                    echo "🎉 DÉPLOIEMENT COMPLET RÉUSSI !"
                    echo "=============================================="
                    echo ""
                    echo "📊 RÉSUMÉ :"
                    echo "• Application: ${APP_URL}${CONTEXT_PATH}/swagger-ui.html"
                    echo "• Image Docker: ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                    echo "• Namespace Kubernetes: ${K8S_NAMESPACE}"
                    echo "• Build: #${BUILD_NUMBER}"
                    echo "• SonarQube: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
                    echo ""
                    echo "📦 État Kubernetes:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                    echo ""
                    echo "=============================================="
                """
            }
        }
        
        failure {
            echo '❌❌❌ PIPELINE ÉCHOUÉE ❌❌❌'
            script {
                sh '''
                    echo "🔧 DÉBOGAGE :"
                    echo "1. État des pods:"
                    kubectl get pods -n devops 2>/dev/null || echo "Erreur kubectl"
                    echo ""
                    echo "2. Logs des pods:"
                    kubectl logs -l app=spring-app -n devops --tail=50 2>/dev/null || echo "Pas de logs disponibles"
                    echo ""
                    echo "3. Événements Kubernetes:"
                    kubectl get events -n devops --sort-by='.lastTimestamp' 2>/dev/null || echo "Pas d'événements"
                '''
            }
        }
        
        always {
            echo '🏁 Pipeline terminée.'
            script {
                echo "📈 Informations de build:"
                echo "   Durée: ${currentBuild.durationString}"
                echo "   Résultat: ${currentBuild.result}"
                echo "   URL du build: ${env.BUILD_URL}"
            }
            
            // Nettoyage si nécessaire
            sh '''
                echo "Nettoyage des images Docker intermédiaires..."
                docker images -f "dangling=true" -q | xargs -r docker rmi || true
            '''
        }
    }
    
    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }
    
    // Déclencheurs (optionnels)
    triggers {
        // Déclenchement par webhook GitHub
        githubPush()
        
        // Ou planification périodique
        // cron('H */4 * * *')
    }
}
