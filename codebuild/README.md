## aws service

- CodeCommit
- CodeBuild
- CodePipeline

In China, other code repo services are not available due to GFW, only CodeCommit is available because it is host within China network.

The challenge is we use github account to manage our code development, and we use two aws accounts, it means we need to maintain three code repos for one copy of project code.

Another challenge is each service is charging us money. For code pipeline, every repo will take $12/year. We have many repos. This cost can be saved if we use other cicd service.

## Terraform configs

This directory provdes some terraform configuration file examples to run above code services.
