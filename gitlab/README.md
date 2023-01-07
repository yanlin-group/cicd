## Current Tool

Gitlab has company in China https://jihulab.com/, and this is the tool we currently use for our code development and deployment in China network.

## Register Docker Runner

Check [DID](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker)

```
sudo gitlab-runner register -n \
  --url https://jihulab.com/ \
  --registration-token SOME_TOKEN \
  --executor docker \
  --description "My Docker Runner" \
  --docker-image "docker:20.10.16" \
  --docker-privileged \
  --docker-volumes "/certs/client"
```

Although runner can be registered to use TLS, in practice, it doesn't work. I have to disable TLS to make docker command working.

## Custom image as the build image

Due to China GFW, the common images are blocked. What I did is to build a custom image from below gitlab image, and push the image registry into my own gitlab image registery in China, and then use this custom image registry as base build image in gitlab.

Base image build Dockefile

```
FROM registry.gitlab.com/gitlab-org/cloud-deploy/aws-base:latest
```
