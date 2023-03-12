# Builds the custom Kafka Connect Docker image with Apicurio converters and Debezium connectors
#

TAG=strimzi-kafka-connect:1
#REGISTRY_PATH=kmon-net-ecr-registry.eu-central-1.cr.aliyuncs.com/kmon-net-cn/$TAG
REGISTRY_PATH=codedroid/$TAG
wget "https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/1.4.2.Final/debezium-connector-postgres-1.4.2.Final-plugin.tar.gz" -O debezium-connector-postgres.tar.gz
wget "https://repo1.maven.org/maven2/io/apicurio/apicurio-registry-distro-connect-converter/1.3.2.Final/apicurio-registry-distro-connect-converter-1.3.2.Final-converter.tar.gz" -O apicurio-registry-distro-connect-converter.tar.gz
tar xvfz debezium-connector-postgres.tar.gz
mkdir apicurio-registry-distro-connect-converter
tar xvfz apicurio-registry-distro-connect-converter.tar.gz --directory apicurio-registry-distro-connect-converter/
docker build -t $TAG -f Dockerfile-kafka-connect .
rm -rf debezium-connector-postgres*
rm -rf apicurio-registry-distro-connect-converter*
docker tag $TAG $REGISTRY_PATH
docker push $REGISTRY_PATH
