pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code source...'
            }
        }
        
        stage('Build') {
            steps {
                echo '🔨 Compilation du projet...'
                // SKIP TESTS pour éviter l'erreur MySQL
                sh 'mvn clean compile -DskipTests'
            }
        }
        
        stage('Package') {
            steps {
                echo '📦 Création du package...'
                sh 'mvn package -DskipTests'
            }
            
            post {
                success {
                    archiveArtifacts 'target/*.jar'
                }
            }
        }
    }
    
    post {
        always {
            echo '🏁 Pipeline terminée!'
        }
        success {
            echo '✅ SUCCÈS!'
        }
        failure {
            echo '❌ ÉCHEC!'
        }
    }
}
