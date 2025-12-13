pipeline {
    agent any
    
    environment {
        // Définit les chemins directement
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        PATH = "${env.JAVA_HOME}/bin:${env.PATH}:/usr/bin"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code source...'
            }
        }
        
        stage('Build') {
            steps {
                echo '🔨 Compilation...'
                sh '''
                    java -version
                    mvn --version
                    mvn clean compile
                '''
            }
        }
        
        stage('Test') {
            steps {
                echo '🧪 Tests...'
                sh 'mvn test'
            }
            
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Package') {
            steps {
                echo '📦 Package...'
                sh 'mvn package'
            }
        }
    }
    
    post {
        always {
            echo '🏁 Pipeline terminée!'
        }
    }
}
