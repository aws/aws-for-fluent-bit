FROM openjdk:16-alpine3.13

WORKDIR /jars
COPY /target/my-app-1.0-SNAPSHOT-jar-with-dependencies.jar /jars/my-app-1.0-SNAPSHOT-jar-with-dependencies.jar

ENTRYPOINT ["java", "-jar", "/jars/my-app-1.0-SNAPSHOT-jar-with-dependencies.jar"]
