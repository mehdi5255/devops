pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Récupération du code source...'
                // Ajoutez ici votre checkout Git si nécessaire
                // git 'https://github.com/votre-utilisateur/votre-repo.git'
            }
        }
        
        stage('Build') {
            steps {
                echo '🔨 Compilation du projet...'
                sh 'mvn clean compile -DskipTests'
            }
        }
        
        stage('Package') {
            steps {
                echo '📦 Création du package...'
                sh 'mvn package -DskipTests'
            }
        }
        
        stage('Analyse SonarQube') {
            steps {
                echo '🔍 Analyse du code avec SonarQube...'
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        mvn sonar:sonar \
                        -Dsonar.projectKey=mon-projet-java \
                        -Dsonar.host.url=http://localhost:9000 \
                        -Dsonar.login=sq_9dfd56b70854582df400349256dce941cf690da3
                    '''
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                echo '⚡ Attente du résultat Quality Gate...'
                timeout(time: 1, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }
    
    post {
        always {
            echo '🏁 Pipeline terminée!'
            archiveArtifacts 'target/*.jar'
        }
        success {
            echo '✅ SUCCÈS! ✅ Analyse SonarQube terminée avec succès!'
        }
        failure {
            echo '❌ ÉCHEC! ❌ Pipeline ou Quality Gate échouée.'
        }
    }
}
