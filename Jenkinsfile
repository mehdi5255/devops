pipeline {
    agent any
    
    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }
    
    environment {
        // Git
        GIT_REPO = 'https://github.com/votre-org/student-management.git'
        GIT_BRANCH = 'main'
        
        // SonarQube
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'student-management'
        SONAR_PROJECT_NAME = 'Student Management System'
        
        // Application
        APP_NAME = 'spring-app'
        APP_VERSION = "${BUILD_NUMBER}"
        
        // Docker
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_USERNAME = 'mehdi002'
        DOCKER_IMAGE_NAME = 'spring-app'
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${DOCKER_IMAGE_NAME}"
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // Kubernetes
        K8S_NAMESPACE = 'devops'
        K8S_DEPLOYMENT = 'spring-app'
        K8S_SERVICE = 'spring-service'
        APP_URL = 'http://192.168.49.2:30080'
        
        // Quality Gates
        SONAR_QG_TIMEOUT = '5'
    }
    
    stages {
        // Stage 1: Checkout
        stage('Checkout Code') {
            steps {
                echo '📥 Cloning repository...'
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${GIT_BRANCH}"]],
                    extensions: [],
                    userRemoteConfigs: [[
                        url: "${GIT_REPO}",
                        credentialsId: 'git-credentials'
                    ]]
                ])
                
                script {
                    // Get commit info for traceability
                    COMMIT_HASH = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    COMMIT_AUTHOR = sh(script: "git --no-pager show -s --format='%an'", returnStdout: true).trim()
                    echo "Commit: ${COMMIT_HASH} by ${COMMIT_AUTHOR}"
                }
            }
        }
        
        // Stage 2: Dependency Check
        stage('Dependency Analysis') {
            steps {
                echo '📦 Checking dependencies...'
                sh 'mvn dependency:tree -DoutputFile=target/dependencies.txt'
                sh 'mvn dependency:check'
            }
        }
        
        // Stage 3: Build
        stage('Build Application') {
            steps {
                echo '🔨 Building application...'
                sh '''
                    mvn clean compile \
                    -DskipTests=true \
                    -Dcheckstyle.skip=true \
                    -Dspotbugs.skip=true
                '''
            }
            
            post {
                success {
                    echo '✅ Build successful'
                }
                failure {
                    echo '❌ Build failed'
                    error 'Build phase failed'
                }
            }
        }
        
        // Stage 4: Unit Tests
        stage('Run Unit Tests') {
            steps {
                echo '🧪 Running unit tests...'
                sh '''
                    mvn test \
                    -DskipTests=false \
                    -DfailIfNoTests=false \
                    -DtestFailureIgnore=false
                '''
            }
            
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    archiveArtifacts 'target/*.jar'
                }
                success {
                    echo '✅ All tests passed'
                }
                failure {
                    echo '❌ Tests failed'
                    script {
                        // Optional: Send test failure notification
                    }
                }
            }
        }
        
        // Stage 5: SonarQube Analysis
        stage('SonarQube Code Analysis') {
            steps {
                echo '🔍 Running SonarQube analysis...'
                script {
                    // Verify SonarQube is reachable
                    try {
                        sh """
                            curl -s -f ${SONAR_HOST_URL}/api/system/status
                            echo "SonarQube server is reachable"
                        """
                    } catch (Exception e) {
                        error "SonarQube server is not reachable at ${SONAR_HOST_URL}"
                    }
                }
                
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_AUTH_TOKEN')]) {
                        sh """
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.projectName="${SONAR_PROJECT_NAME}" \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.login=${SONAR_AUTH_TOKEN} \
                                -Dsonar.projectVersion=${APP_VERSION} \
                                -Dsonar.sourceEncoding=UTF-8 \
                                -Dsonar.java.source=17 \
                                -Dsonar.java.target=17 \
                                -Dsonar.sources=src/main/java \
                                -Dsonar.tests=src/test/java \
                                -Dsonar.junit.reportsPath=target/surefire-reports \
                                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                                -Dsonar.qualitygate.wait=true
                        """
                    }
                }
            }
            
            post {
                success {
                    echo '✅ SonarQube analysis completed'
                    script {
                        SONAR_URL = "${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
                        echo "SonarQube Dashboard: ${SONAR_URL}"
                    }
                }
                failure {
                    echo '❌ SonarQube analysis failed'
                }
            }
        }
        
        // Stage 6: Quality Gate Check
        stage('Check Quality Gate') {
            steps {
                echo '⚡ Checking Quality Gate status...'
                timeout(time: SONAR_QG_TIMEOUT, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
            
            post {
                success {
                    echo '✅ Quality Gate passed'
                }
                failure {
                    echo '❌ Quality Gate failed'
                    script {
                        currentBuild.result = 'FAILURE'
                        error "Quality Gate failed. Check SonarQube dashboard: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
                    }
                }
            }
        }
        
        // Stage 7: Package Application
        stage('Package Application') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '📦 Packaging application...'
                sh 'mvn package -DskipTests'
                
                script {
                    // Find the generated JAR file
                    JAR_FILE = sh(script: 'find target -name "*.jar" -type f | head -1', returnStdout: true).trim()
                    echo "Generated JAR: ${JAR_FILE}"
                    env.JAR_FILE = JAR_FILE
                }
            }
        }
        
        // Stage 8: Build Docker Image
        stage('Build Docker Image') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Setup Docker environment for Minikube if available
                    sh '''
                        if command -v minikube &> /dev/null; then
                            echo "Setting up Minikube Docker environment..."
                            eval $(minikube docker-env)
                            echo "Docker will use Minikube's Docker daemon"
                        else
                            echo "Using system Docker daemon"
                        fi
                    '''
                    
                    // Build Docker image
                    sh """
                        docker build \
                            --no-cache \
                            --build-arg JAR_FILE=${env.JAR_FILE} \
                            -t ${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -t ${DOCKER_IMAGE}:latest \
                            -t ${DOCKER_IMAGE}:${COMMIT_HASH} \
                            .
                        
                        # Verify image was created
                        echo "Docker images created:"
                        docker images | grep ${DOCKER_USERNAME}
                        
                        # Optional: Push to registry
                        # docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        # docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
        
        // Stage 9: Deploy to Kubernetes
        stage('Deploy to Kubernetes') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '🚀 Deploying to Kubernetes...'
                script {
                    // Verify Kubernetes access
                    sh """
                        echo "Kubernetes context:"
                        kubectl config current-context
                        
                        echo "Kubernetes nodes:"
                        kubectl get nodes
                        
                        echo "Current deployment status:"
                        kubectl get deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} || echo "Deployment not found"
                    """
                    
                    // Update deployment
                    sh """
                        # Update image in deployment
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                            ${APP_NAME}=${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -n ${K8S_NAMESPACE} --record
                        
                        # Restart deployment
                        kubectl rollout restart deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE}
                        
                        # Wait for rollout to complete
                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                            -n ${K8S_NAMESPACE} --timeout=300s
                        
                        # Verify pods
                        echo "Updated pods:"
                        kubectl get pods -n ${K8S_NAMESPACE} -l app=${K8S_DEPLOYMENT} -o wide
                    """
                }
            }
            
            post {
                success {
                    echo '✅ Deployment successful'
                }
                failure {
                    echo '❌ Deployment failed'
                    script {
                        sh """
                            echo "Debugging deployment failure..."
                            kubectl describe deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                            kubectl get events -n ${K8S_NAMESPACE} --sort-by='.lastTimestamp' | tail -20
                        """
                    }
                }
            }
        }
        
        // Stage 10: Health Check
        stage('Health Check & Smoke Tests') {
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') }
            }
            steps {
                echo '🏥 Performing health check...'
                script {
                    retry(3) {
                        timeout(time: 2, unit: 'MINUTES') {
                            sh """
                                # Wait for application to be ready
                                echo "Waiting for application to start..."
                                sleep 15
                                
                                # Try health endpoint first
                                echo "Testing /actuator/health..."
                                if curl -s -f ${APP_URL}/actuator/health > /dev/null; then
                                    echo "✅ Application health check passed"
                                else
                                    echo "⚠️  Actuator health not available, trying main endpoint..."
                                    # Fallback to main endpoint
                                    curl -s -f ${APP_URL}/student/Department/getAllDepartment || exit 1
                                    echo "✅ Application is responding"
                                fi
                                
                                # Additional smoke tests
                                echo "Running smoke tests..."
                                # Test Swagger UI
                                curl -s -I ${APP_URL}/student/swagger-ui.html | head -1
                                echo "Smoke tests completed"
                            """
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ ✅ ✅ PIPELINE SUCCESSFUL ✅ ✅ ✅'
            script {
                echo """
                ===========================================
                🎉 DEPLOYMENT SUMMARY
                ===========================================
                
                📊 APPLICATION INFO:
                • Application: ${APP_NAME}
                • Version: ${APP_VERSION}
                • Commit: ${COMMIT_HASH}
                • Build: #${BUILD_NUMBER}
                
                🔗 URLs:
                • Application: ${APP_URL}/student/swagger-ui.html
                • Health Check: ${APP_URL}/actuator/health
                • SonarQube: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}
                
                🐳 DOCKER INFO:
                • Image: ${DOCKER_IMAGE}:${DOCKER_TAG}
                • Tag: ${DOCKER_TAG}
                
                ☸️ KUBERNETES INFO:
                • Namespace: ${K8S_NAMESPACE}
                • Deployment: ${K8S_DEPLOYMENT}
                
                ===========================================
                """
                
                // Display current pods status
                sh """
                    echo "Current pods status:"
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    
                    echo ""
                    echo "Service endpoints:"
                    kubectl get svc -n ${K8S_NAMESPACE}
                """
            }
        }
        
        failure {
            echo '❌ ❌ ❌ PIPELINE FAILED ❌ ❌ ❌'
            script {
                echo """
                ===========================================
                🔴 DEPLOYMENT FAILURE
                ===========================================
                
                Pipeline failed at stage: ${env.STAGE_NAME}
                Build: #${BUILD_NUMBER}
                Commit: ${COMMIT_HASH}
                
                Last error: ${currentBuild.currentResult}
                ===========================================
                """
                
                // Enhanced debugging information
                sh """
                    echo "=== DEBUG INFORMATION ==="
                    echo ""
                    echo "1. KUBERNETES STATUS:"
                    kubectl get all -n ${K8S_NAMESPACE}
                    echo ""
                    
                    echo "2. POD DETAILS:"
                    kubectl describe pods -n ${K8S_NAMESPACE} -l app=${K8S_DEPLOYMENT} 2>/dev/null | tail -50 || echo "No pod details"
                    echo ""
                    
                    echo "3. DEPLOYMENT EVENTS:"
                    kubectl get events -n ${K8S_NAMESPACE} --sort-by='.lastTimestamp' | tail -30
                    echo ""
                    
                    echo "4. APPLICATION LOGS:"
                    kubectl logs -n ${K8S_NAMESPACE} -l app=${K8S_DEPLOYMENT} --tail=100 2>/dev/null || echo "No logs available"
                    echo ""
                    
                    echo "5. DOCKER IMAGES:"
                    docker images | grep ${DOCKER_USERNAME} || echo "No Docker images found"
                """
            }
        }
        
        always {
            echo '🏁 Pipeline execution completed'
            script {
                // Cleanup
                sh '''
                    echo "Cleaning up temporary files..."
                    rm -f pom.xml.versionsBackup || true
                    
                    echo "Build duration: ${currentBuild.durationString}"
                    echo "Final result: ${currentBuild.currentResult}"
                '''
                
                // Clean Docker images if needed
                sh '''
                    if [ "${currentBuild.currentResult}" = "SUCCESS" ]; then
                        echo "Keeping Docker images for successful build"
                    else
                        echo "Cleaning up Docker images..."
                        docker image prune -f 2>/dev/null || true
                    fi
                '''
            }
        }
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '30'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        retry(0)
    }
    
    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip unit tests')
        booleanParam(name: 'SKIP_SONAR', defaultValue: false, description: 'Skip SonarQube analysis')
        booleanParam(name: 'SKIP_DEPLOY', defaultValue: false, description: 'Skip Kubernetes deployment')
    }
}
