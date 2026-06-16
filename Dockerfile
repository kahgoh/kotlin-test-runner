# === Build builder image ===

FROM docker.io/library/gradle:9.5.1-jdk25@sha256:8de3543f1772bb66be3b275893e5977b6d8bd2b0d25551faa5846a821d1f0600 AS build

WORKDIR /home/builder

# Prepare required project files
COPY lib/ ./

# Build test runner
RUN gradle --no-daemon -i shadowJar \
    && cp build/libs/autotest-runner.jar .

FROM docker.io/library/maven:3.9.16-eclipse-temurin-25-alpine@sha256:1a1f3bd96046f84c5beeb1f28bf909f9618b9dd6ef8d5af404e82dc67cf2cef9 AS cache

# Ensure exercise dependencies are downloaded
WORKDIR /opt/exercise
COPY examples/full .
COPY examples/template/pom.xml .
RUN mvn test dependency:go-offline -DexcludeReactor=false

# === Build runtime image ===

FROM docker.io/library/maven:3.9.16-eclipse-temurin-25-alpine@sha256:1a1f3bd96046f84c5beeb1f28bf909f9618b9dd6ef8d5af404e82dc67cf2cef9
WORKDIR /opt/test-runner

# Copy binary and launcher script
COPY bin/ bin/
COPY --from=build /home/builder/autotest-runner.jar ./

# Copy cached dependencies
COPY --from=cache /root/.m2 /root/.m2

# Copy Maven pom.xml
COPY --from=cache /opt/exercise/pom.xml /root/pom.xml

ENTRYPOINT ["sh", "/opt/test-runner/bin/run.sh"]
