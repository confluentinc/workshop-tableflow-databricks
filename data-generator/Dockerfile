FROM gradle:8-jdk21 AS build
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY src ./src
RUN gradle shadowJar --no-daemon

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
COPY --from=build /app/build/libs/*-all.jar /app/datagen.jar
EXPOSE 9400
ENTRYPOINT ["java", "-jar", "/app/datagen.jar"]
