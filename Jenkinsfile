pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build & Package') {
            steps {
                sh '''
                    mvn clean compile -DskipTests
                    mvn package -DskipTests
                '''
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        // Utilisez sonar.token au lieu du déprécié sonar.login
                        sh """
                            mvn sonar:sonar \
                              -Dsonar.projectKey=student-management \
                              -Dsonar.host.url=http://localhost:9000 \
                              -Dsonar.token=${SONAR_TOKEN} \
                              -Dsonar.skipTests=true
                        """
                    }
                }
            }
        }
        
        stage('Docker Build') {
            // Cette étape s'exécutera même si SonarQube a des avertissements
            when {
                expression { currentBuild.resultIsBetterOrEqualTo('UNSTABLE') }
            }
            steps {
                script {
                    // Essaie avec sudo, au cas où
                    try {
                        sh "sudo docker build -t mehdi002/spring-app:${BUILD_NUMBER} ."
                    } catch (Exception e) {
                        echo "⚠️  Échec avec sudo, tentative sans..."
                        sh "docker build -t mehdi002/spring-app:${BUILD_NUMBER} ."
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "🚀 Pipeline terminée. Résultat : ${currentBuild.currentResult}"
            echo "📊 Rapport SonarQube : http://localhost:9000/dashboard?id=student-management"
        }
    }
}
