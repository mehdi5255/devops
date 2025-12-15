# Version simplifiée pour tests
FROM openjdk:17-alpine

WORKDIR /app

# Copier directement le JAR (si construit en local)
COPY target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
