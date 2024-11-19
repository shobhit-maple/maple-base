FROM bitnami/kubectl:latest

USER root

RUN apt-get update && \
    apt-get install -y curl jq && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /scripts
COPY k8s-redeployer.sh /scripts/k8s-redeployer.sh

USER root
RUN chmod +x /scripts/k8s-redeployer.sh
USER 1001

ENTRYPOINT ["/scripts/k8s-redeployer.sh"]
