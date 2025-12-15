# Dockerfile EXACT qui a fonctionné pour vous
FROM alpine:3.23.0

WORKDIR /app

# Installer Java 17 (comme dans votre image)
RUN apk add --no-cache openjdk17-jre

# Copier le JAR
COPY target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
