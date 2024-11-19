#!/bin/bash

COMPONENT_NAME=$1
NAMESPACE="maple-system"
TAG="latest"

get_image_digest() {
    local docker_image=$1
    echo "Fetching digest for $docker_image:$TAG" >&2
    tag_response=$(curl -s "https://registry.hub.docker.com/v2/repositories/$docker_image/tags/$TAG/")
    digest=$(echo "$tag_response" | jq -r '.images[0].digest')

    if [ "$digest" == "null" ] || [ -z "$digest" ]; then
        echo "Error fetching digest. Response: $tag_response"
        exit 1
    fi
    echo $digest
}

deploy_if_updated() {
    local component_name=$1
    local deployment_name="${component_name}-deployment"
    local container_name="${component_name}-container"
    local docker_image="shobhittyagi1011/${component_name}-service"

    current_digest=$(kubectl get deployment "$deployment_name" -n "$NAMESPACE" -o json | jq -r ".spec.template.spec.containers[0].image" | sed "s|.*@||")

    digest=$(get_image_digest "$docker_image")
    if [ "$current_digest" != "$digest" ]; then
        echo "Image has been updated for $component_name. Redeploying..."
        kubectl set image deployment/"$deployment_name" -n "$NAMESPACE" "$container_name"="$docker_image@$digest"
        kubectl rollout restart deployment/"$deployment_name" -n "$NAMESPACE"
    else
        echo "No update found for $component_name, skipping redeploy."
    fi
}

for COMPONENT_NAME in "$@"; do
    echo "Processing component: $COMPONENT_NAME"
    deploy_if_updated "$COMPONENT_NAME"
done
