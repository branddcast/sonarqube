FROM registry.redhat.io/ubi8/openjdk-11

ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8'

#
# SonarQube setup
#
RUN echo $PATH
ARG SONARQUBE_VERSION=9.2.1.49989
ARG SONARQUBE_PORT=9000
ARG SONARQUBE_ZIP_URL=https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip
ENV PATH="/opt/java/openjdk/bin:$PATH" \
    SONARQUBE_HOME=/opt/sonarqube \
    SONAR_VERSION="${SONARQUBE_VERSION}" \
    SQ_DATA_DIR="/opt/sonarqube/data" \
    SQ_EXTENSIONS_DIR="/opt/sonarqube/extensions" \
    SQ_LOGS_DIR="/opt/sonarqube/logs" \
    SQ_TEMP_DIR="/opt/sonarqube/temp"

USER root

RUN cd /opt; ls; cd run-java; ls;
 
RUN set -eux; \
    echo "networkaddress.cache.ttl=5" >> "${JAVA_HOME}/conf/security/java.security"; \
    sed --in-place --expression="s?securerandom.source=file:/dev/random?securerandom.source=file:/dev/urandom?g" "${JAVA_HOME}/conf/security/java.security"; \
    for server in $(shuf -e ha.pool.sks-keyservers.net \
                            hkp://p80.pool.sks-keyservers.net:80 \
                            keyserver.ubuntu.com \
                            hkp://keyserver.ubuntu.com:80 \
                            pgp.mit.edu) ; do \
        gpg --batch --keyserver "${server}" --recv-keys 679F1EE92B19609DE816FDE81DB198F93525EC1A && break || : ; \
    done; \
    mkdir --parents /opt; \
    cd /opt; \
    curl --fail --location --output sonarqube.zip --silent --show-error "${SONARQUBE_ZIP_URL}"; \
    curl --fail --location --output sonarqube.zip.asc --silent --show-error "${SONARQUBE_ZIP_URL}.asc"; \
    gpg --batch --verify sonarqube.zip.asc sonarqube.zip; \
    unzip -q sonarqube.zip; \
    mv "sonarqube-${SONARQUBE_VERSION}" sonarqube; \
    rm sonarqube.zip*; \
    rm -rf ${SONARQUBE_HOME}/bin/*; \
    # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
    chmod -R 777 "${SQ_DATA_DIR}" "${SQ_EXTENSIONS_DIR}" "${SQ_LOGS_DIR}" "${SQ_TEMP_DIR}"; 

COPY /tmp/build/inputs/run.sh /tmp/build/inputs/sonar.sh ${SONARQUBE_HOME}/bin/

WORKDIR ${SONARQUBE_HOME}
EXPOSE ${SONARQUBE_PORT}

STOPSIGNAL SIGINT

ENTRYPOINT ["/opt/sonarqube/bin/run.sh"]
CMD ["/opt/sonarqube/bin/sonar.sh"]
