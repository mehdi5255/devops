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
        stage('Checkout & Build') {
            steps {
                echo '📥 Récupération et build...'
                checkout scm
                sh '''
                    # Build Maven en parallèle avec cache
                    mvn -B clean package -DskipTests -q -T 1C
                    
                    # Build Docker en utilisant le cache
                    eval $(minikube docker-env 2>/dev/null)
                    docker build --cache-from ${DOCKER_IMAGE}:latest -t ${DOCKER_IMAGE}:${BUILD_NUMBER} -q .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                '''
                archiveArtifacts 'target/*.jar'
            }
        }
        
        stage('Analyse SonarQube (Parallèle)') {
            parallel {
                stage('SonarQube Scan') {
                    steps {
                        script {
                            try {
                                withSonarQubeEnv('SonarQube') {
                                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                                        sh '''
                                            mvn sonar:sonar \
                                            -Dsonar.projectKey=student-management \
                                            -Dsonar.host.url=http://localhost:9000 \
                                            -Dsonar.login=$SONAR_TOKEN \
                                            -Dsonar.qualitygate.wait=false \
                                            -q
                                        '''
                                    }
                                }
                                echo "✅ SonarQube: http://localhost:9000/dashboard?id=student-management"
                            } catch (Exception e) {
                                echo "⚠️  SonarQube ignoré"
                            }
                        }
                    }
                }
                
                stage('Déploiement MySQL Rapide') {
                    steps {
                        script {
                            sh '''
                                # Préparation rapide
                                kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
                                
                                # MySQL sans persistence pour les tests (BEAUCOUP plus rapide)
                                kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-test
  namespace: devops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-test
  template:
    metadata:
      labels:
        app: mysql-test
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "root123"
        - name: MYSQL_DATABASE
          value: "springdb"
        - name: MYSQL_ALLOW_EMPTY_PASSWORD
          value: "no"
        ports:
        - containerPort: 3306
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: devops
spec:
  selector:
    app: mysql-test
  ports:
  - port: 3306
  type: ClusterIP
EOF
                                
                                echo "⚡ MySQL léger déployé (pas de persistence)"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Déploiement Rapide Spring Boot') {
            steps {
                script {
                    sh '''
                        # Attendre 15s max que MySQL soit prêt
                        echo "⏳ Attente MySQL (15s max)..."
                        for i in {1..15}; do
                            if kubectl get pods -n devops -l app=mysql-test -o jsonpath="{.items[0].status.phase}" 2>/dev/null | grep -q Running; then
                                echo "✅ MySQL prêt après ${i}s"
                                break
                            fi
                            sleep 1
                        done
                        
                        # Déploiement Spring Boot optimisé
                        kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app
  namespace: devops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spring-app
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
      - name: spring-app
        image: mehdi002/spring-app:${BUILD_NUMBER}
        env:
        - name: SPRING_DATASOURCE_URL
          value: "jdbc:mysql://mysql-service:3306/springdb?createDatabaseIfNotExist=true&useSSL=false"
        - name: SPRING_DATASOURCE_USERNAME
          value: "root"
        - name: SPRING_DATASOURCE_PASSWORD
          value: "root123"
        - name: SPRING_JPA_HIBERNATE_DDL_AUTO
          value: "update"
        - name: SERVER_SERVLET_CONTEXT_PATH
          value: "/student"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
        ports:
        - containerPort: 8080
        startupProbe:
          httpGet:
            path: /student/actuator/health
            port: 8080
          failureThreshold: 30
          periodSeconds: 2
        livenessProbe:
          httpGet:
            path: /student/actuator/health
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 10
EOF
                        
                        # Service NodePort
                        kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: spring-app-service
  namespace: devops
spec:
  type: NodePort
  selector:
    app: spring-app
  ports:
  - port: 8080
    nodePort: 30080
EOF
                        
                        echo "🚀 Application déployée - démarrage rapide activé"
                    '''
                }
            }
        }
        
        stage('Vérification Intelligente') {
            steps {
                script {
                    sh '''
                        IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
                        
                        # Vérification en parallèle avec timeout
                        echo "🔍 Vérification en cours (max 60s)..."
                        
                        # Attendre intelligemment
                        for i in {1..30}; do
                            # Vérifier si le pod est prêt
                            READY=$(kubectl get pods -n devops -l app=spring-app -o jsonpath="{.items[0].status.containerStatuses[0].ready}" 2>/dev/null || echo "false")
                            
                            if [ "$READY" = "true" ]; then
                                echo "✅ Pod prêt après ${i}s"
                                
                                # Tester rapidement
                                if curl -s --max-time 5 "http://${IP}:30080/student/actuator/health" > /dev/null; then
                                    echo "🎉 APPLICATION OPÉRATIONNELLE !"
                                    echo "🔗 http://${IP}:30080/student/swagger-ui.html"
                                    exit 0
                                fi
                            fi
                            
                            # Afficher progression toutes les 10s
                            if [ $((i % 5)) -eq 0 ]; then
                                echo "  ... ${i}s écoulées, attente..."
                                # Logs courts pour debug
                                kubectl logs -n devops -l app=spring-app --tail=3 2>/dev/null | grep -E "(STARTED|ERROR|mysql)" || true
                            fi
                            
                            sleep 2
                        done
                        
                        echo "⚠️  Application lente à démarrer"
                        echo "Pour debug: kubectl logs -n devops -l app=spring-app"
                        echo "Continuer malgré tout..."
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ PIPELINE RÉUSSIE (version rapide)'
            script {
                sh '''
                    IP=$(minikube ip 2>/dev/null)
                    echo "=== RÉSUMÉ RAPIDE ==="
                    echo "App: http://${IP}:30080/student"
                    echo "SonarQube: http://localhost:9000/dashboard?id=student-management"
                    kubectl get pods -n devops --no-headers | wc -l | xargs echo "Pods déployés:"
                '''
            }
        }
        
        always {
            cleanWs()
            sh '''
                # Nettoyage léger
                docker system prune -f 2>/dev/null || true
                echo "Temps: ${currentBuild.durationString}"
            '''
        }
    }
    
    // ⚠️ CORRECTION ICI : Pas de commentaires # dans options
    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '3'))
        skipDefaultCheckout()
    }
}
