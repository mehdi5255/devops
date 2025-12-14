pipeline {
    agent any
    
    environment {
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'student-management'
        SONAR_PROJECT_NAME = 'Student Management System'
        
        // Docker
        DOCKER_IMAGE = 'mehdi002/spring-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
        APP_URL = 'http://192.168.49.2:30080'
        
        // Quality Gates
        SONAR_QG_TIMEOUT = '5'
    }
    
    stages {
        // Stage 1: Checkout
        stage('Checkout Code') {
            steps {
                echo '📥 Cloning repository...'
                checkout scm
                
                script {
                    COMMIT_HASH = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    echo "Commit: ${COMMIT_HASH}"
                }
            }
        }
        
        // Stage 2: Build
        stage('Build Application') {
            steps {
                echo '🔨 Building application...'
                sh 'mvn clean compile -DskipTests'
            }
            
            post {
                success {
                    echo '✅ Build successful'
                }
                failure {
                    error '❌ Build failed'
                }
            }
        }
        
        // Stage 3: Unit Tests
        stage('Run Unit Tests') {
            steps {
                echo '🧪 Running unit tests...'
                sh 'mvn test'
            }
            
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        
        // Stage 4: SonarQube Analysis
        stage('SonarQube Code Analysis') {
            steps {
                echo '🔍 Running SonarQube analysis...'
                
                sh """
                    echo "Checking SonarQube..."
                    curl -s ${SONAR_HOST_URL}/api/system/status || echo "SonarQube check"
                """
                
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.projectName="${SONAR_PROJECT_NAME}" \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dsonar.sourceEncoding=UTF-8 \
                                -Dsonar.sources=src/main/java \
                                -Dsonar.tests=src/test/java \
                                -Dsonar.junit.reportsPath=target/surefire-reports
                        """
                    }
                }
            }
            
            post {
                success {
                    echo '✅ SonarQube analysis completed'
                }
            }
        }
        
        // Stage 5: Quality Gate Check
        stage('Check Quality Gate') {
            steps {
                echo '⚡ Checking Quality Gate status...'
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        // Stage 6: Package Application
        stage('Package Application') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '📦 Packaging application...'
                sh 'mvn package -DskipTests'
                
                script {
                    JAR_FILE = sh(script: 'find target -name "*.jar" -type f | head -1', returnStdout: true).trim()
                    env.JAR_FILE = JAR_FILE
                }
            }
        }
        
        // Stage 7: Build Docker Image
        stage('Build Docker Image') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '🐳 Building Docker image...'
                script {
                    sh '''
                        if command -v minikube &> /dev/null; then
                            eval $(minikube docker-env)
                        fi
                    '''
                    
                    sh """
                        docker build \
                            --build-arg JAR_FILE=${env.JAR_FILE} \
                            -t ${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -t ${DOCKER_IMAGE}:latest \
                            .
                        
                        docker images | grep ${DOCKER_IMAGE} || true
                    """
                }
            }
        }
        
        // Stage 8: Deploy to Kubernetes
        stage('Deploy to Kubernetes') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '🚀 Deploying to Kubernetes...'
                script {
                    sh """
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            spring-app=${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -n ${K8S_NAMESPACE} --record
                        
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE}
                        
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE} --timeout=300s
                        
                        kubectl get pods -n ${K8S_NAMESPACE} -l app=${K8S_DEPLOYMENT}
                    """
                }
            }
        }
        
        // Stage 9: Health Check
        stage('Health Check') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '🏥 Performing health check...'
                script {
                    retry(3) {
                        timeout(time: 2, unit: 'MINUTES') {
                            sh """
                                sleep 20
                                curl -f ${APP_URL}/student/Department/getAllDepartment || exit 1
                                echo "✅ Application is responding"
                            """
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ PIPELINE SUCCESSFUL'
            script {
                sh """
                    echo "Application: ${APP_URL}"
                    echo "SonarQube: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
                    kubectl get pods -n ${K8S_NAMESPACE}
                """
            }
        }
        
        failure {
            echo '❌ PIPELINE FAILED'
            script {
                sh """
                    echo "Debugging..."
                    kubectl get all -n ${K8S_NAMESPACE}
                    kubectl logs -n ${K8S_NAMESPACE} -l app=${K8S_DEPLOYMENT} --tail=50 2>/dev/null || echo "No logs"
                """
            }
        }
        
        always {
            echo '🏁 Pipeline completed'
        }
    }
    
    options {
        timeout(time: 30, unit: 'MINUTES')
    }
}
