# ---------- Etapa 1: compilar con Maven ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Primero solo el pom.xml: asi Docker cachea las dependencias
COPY pom.xml .
RUN mvn -q dependency:go-offline

COPY src ./src
RUN mvn -q -DskipTests package

# ---------- Etapa 2: imagen ligera solo con el JRE ----------
FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=build /app/target/api-springboot-1.0.0.jar app.jar

# Carpeta donde se guardan los archivos subidos (se monta como volumen)
RUN mkdir -p /app/uploads

EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
