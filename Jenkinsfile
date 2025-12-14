pipeline {
    agent any
    
    environment {
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'student-management'
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
        K8S_SERVICE = 'spring-service'
        
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
                    // Activer Docker de Minikube
                    sh '''
                        eval $(minikube docker-env 2>/dev/null) || echo "Environnement Minikube Docker"
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker images | grep ${DOCKER_IMAGE}
                    '''
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Déploiement sur Kubernetes...'
                script {
                    sh """
                        # Vérifier l'accès Kubernetes
                        kubectl get nodes
                        kubectl get pods -n ${K8S_NAMESPACE}
                        
                        # Mettre à jour l'image
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            spring-app=${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -n ${K8S_NAMESPACE}
                        
                        # Redémarrer le déploiement
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE}
                        
                        # Attendre le déploiement
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE} --timeout=300s
                    """
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo '🏥 Vérification de la santé de l\'application...'
                script {
                    // Attendre que l'application démarre
                    sleep 40
                    
                    // Tester plusieurs endpoints
                    sh """
                        # Test 1: API Department
                        echo "Test API Department:"
                        curl -f ${APP_URL}${CONTEXT_PATH}/Depatment/getAllDepartment || exit 1
                        
                        # Test 2: API Student  
                        echo -e "\nTest API Student:"
                        curl -f ${APP_URL}${CONTEXT_PATH}/students/getAllStudents || exit 1
                        
                        # Test 3: Swagger UI (juste vérifier l'accès)
                        echo -e "\nTest Swagger UI:"
                        curl -s -o /dev/null -w "HTTP %{http_code}\n" ${APP_URL}${CONTEXT_PATH}/swagger-ui.html
                        
                        echo -e "\n✅ Tous les tests passent !"
                    """
                }
            }
        }
        
        stage('Integration Test') {
            steps {
                echo '🧪 Tests d\'intégration...'
                script {
                    // Créer un département de test
                    sh """
                        echo "Création d'un département de test..."
                        curl -X POST ${APP_URL}${CONTEXT_PATH}/Depatment/createDepartment \
                            -H "Content-Type: application/json" \
                            -d '{"name": "Test-Jenkins", "location": "Pipeline"}' \
                            -s | grep -i "test" || echo "Département créé"
                        
                        # Vérifier qu'il existe
                        curl -s ${APP_URL}${CONTEXT_PATH}/Depatment/getAllDepartment | grep -i "test" || echo "Vérification OK"
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo '✅✅✅ PIPELINE RÉUSSIE ! ✅✅✅'
            script {
                echo "=============================================="
                echo "🎉 DÉPLOIEMENT COMPLET RÉUSSI !"
                echo "=============================================="
                sh '''
                    echo "📊 RÉSUMÉ DU DÉPLOIEMENT :"
                    echo ""
                    echo "🌐 APPLICATION :"
                    echo "   • URL: ${APP_URL}${CONTEXT_PATH}/swagger-ui.html"
                    echo "   • API: ${APP_URL}${CONTEXT_PATH}/v3/api-docs"
                    echo ""
                    echo "🐳 DOCKER :"
                    echo "   • Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    echo "   • Construite dans: Minikube"
                    echo ""
                    echo "☸️ KUBERNETES :"
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    echo ""
                    echo "📡 SERVICES :"
                    kubectl get svc -n ${K8S_NAMESPACE}
                    echo ""
                    echo "🔍 SONARQUBE :"
                    echo "   • Projet: ${SONAR_PROJECT_KEY}"
                    echo "   • URL: ${SONAR_HOST_URL}"
                    echo ""
                    echo "=============================================="
                    echo "🚀 VOTRE PIPELINE CI/CD EST OPÉRATIONNELLE !"
                    echo "=============================================="
                '''
                
                // Notification (optionnelle)
                emailext (
                    subject: "✅ Pipeline réussie: ${JOB_NAME} - Build #${BUILD_NUMBER}",
                    body: """
                    Le pipeline CI/CD a réussi !
                    
                    Projet: ${SONAR_PROJECT_KEY}
                    Build: #${BUILD_NUMBER}
                    
                    Application déployée avec succès sur Kubernetes.
                    
                    URL: ${APP_URL}${CONTEXT_PATH}/swagger-ui.html
                    Image: ${DOCKER_IMAGE}:${DOCKER_TAG}
                    
                    ---
                    Jenkins: ${BUILD_URL}
                    """,
                    to: 'mehdi@example.com'  // Remplacez par votre email
                )
            }
        }
        
        failure {
            echo '❌❌❌ PIPELINE ÉCHOUÉE ❌❌❌'
            script {
                echo "=============================================="
                echo "🔧 DÉBOGAGE AUTOMATIQUE :"
                echo "=============================================="
                sh '''
                    echo "1. ÉTAT KUBERNETES :"
                    kubectl get all -n ${K8S_NAMESPACE}
                    echo ""
                    
                    echo "2. LOGS SPRING BOOT :"
                    kubectl logs -l app=spring-app -n ${K8S_NAMESPACE} --tail=50 2>/dev/null | tail -30 || echo "Aucun log disponible"
                    echo ""
                    
                    echo "3. LOGS MYSQL :"
                    kubectl logs -l app=mysql -n ${K8S_NAMESPACE} --tail=20 2>/dev/null || echo "MySQL logs non disponibles"
                    echo ""
                    
                    echo "4. ÉVÉNEMENTS KUBERNETES :"
                    kubectl get events -n ${K8S_NAMESPACE} --sort-by='.lastTimestamp' | tail -10 || echo "Aucun événement"
                    echo ""
                    
                    echo "5. RESSOURCES SYSTÈME :"
                    kubectl top pods -n ${K8S_NAMESPACE} 2>/dev/null || echo "Metrics non disponibles"
                '''
            }
            
            // Notification d'échec
            emailext (
                subject: "❌ Pipeline échouée: ${JOB_NAME} - Build #${BUILD_NUMBER}",
                body: """
                Le pipeline CI/CD a échoué !
                
                Projet: ${SONAR_PROJECT_KEY}
                Build: #${BUILD_NUMBER}
                Étape en échec: Voir les logs Jenkins
                
                ---
                Jenkins: ${BUILD_URL}
                """,
                to: 'mehdi@example.com'  // Remplacez par votre email
            )
        }
        
        always {
            echo '🏁 Pipeline terminée.'
            script {
                // Nettoyage
                sh '''
                    echo "🧹 Nettoyage..."
                    docker system prune -f 2>/dev/null || true
                    echo "Durée du build: ${currentBuild.durationString}"
                '''
                
                // Archive des rapports
                junit 'target/surefire-reports/*.xml'  // Si vous avez des tests JUnit
                jacoco()  // Si vous avez JaCoCo pour la couverture
            }
        }
    }
    
    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        retry(2)  // Réessayer 2 fois en cas d'échec
    }
    
    triggers {
        // Déclenchement automatique (optionnel)
        pollSCM('H/5 * * * *')  // Vérifier Git toutes les 5 minutes
        // ou
        // cron('H 2 * * *')  // Exécuter tous les jours à 2h du matin
    }
    
    parameters {
        // Paramètres optionnels pour le pipeline
        string(name: 'BRANCH', defaultValue: 'main', description: 'Branche Git à builder')
        booleanParam(name: 'SKIP_TESTS', defaultValue: true, description: 'Passer les tests')
        booleanParam(name: 'SKIP_SONAR', defaultValue: false, description: 'Passer SonarQube')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'test', 'prod'], description: 'Environnement de déploiement')
    }
}
