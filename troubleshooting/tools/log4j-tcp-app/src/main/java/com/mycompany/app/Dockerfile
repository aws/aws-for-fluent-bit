FROM openjdk:16-alpine3.13

WORKDIR /jars
# RUN mkdir /jars

COPY my-app-1.0-SNAPSHOT.jar /jars/my-app-1.0-SNAPSHOT.jar
COPY log4j-api-2.17.1.jar /jars/log4j-api-2.17.1.jar
COPY log4j-core-2.17.1.jar /jars/log4j-core-2.17.1.jar
COPY log4j-1.2.17.jar /jars/log4j-1.2.17.jar 

ENTRYPOINT ["java", "-jar", "/jars/my-app-1.0-SNAPSHOT.jar"]
