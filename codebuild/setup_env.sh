export APP=wechat-official-admin
export APP_DOMAIN=official

if [ $GIT_BRANCH == "develop" ]; then
    export ENV=dev
    export CLUSTER_NAME=staging
    export AWS_DEFAULT_REGION=cn-northwest-1
    export AWS_ACCESS_KEY_ID=$STAGING_CODEBUILD_AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY=$STAGING_CODEBUILD_AWS_SECRET_ACCESS_KEY
    export AWS_ACCOUNT_ID=${STAGING_ACCOUNT_ID}
    export DOMAIN_SUFFIX=dev.
    export API_HOST=https://dev.api.yanlin.cn/prefix-wechat-official-api
fi
if [ $GIT_BRANCH == "qa" ]; then
    export ENV=qa
    export CLUSTER_NAME=staging
    export AWS_ACCESS_KEY_ID=${STAGING_CIRCLECI_AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${STAGING_CIRCLECI_AWS_SECRET_ACCESS_KEY}
    export AWS_ACCOUNT_ID=${STAGING_ACCOUNT_ID}
    export DOMAIN_SUFFIX=qa.
    export API_HOST=https://qa.api.yanlin.cn/prefix-wechat-official-api
fi
if [ $GIT_BRANCH == "demo" ]; then
    export ENV=demo
    export CLUSTER_NAME=staging
    export AWS_ACCESS_KEY_ID=${STAGING_CIRCLECI_AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${STAGING_CIRCLECI_AWS_SECRET_ACCESS_KEY}
    export AWS_ACCOUNT_ID=${STAGING_ACCOUNT_ID}
    export DOMAIN_SUFFIX=demo.
    export API_HOST=https://demo.api.yanlin.cn/prefix-wechat-official-api
fi
if [ $GIT_BRANCH == "main" ]; then
    export ENV=prod
    export CLUSTER_NAME=prod
    export AWS_ACCESS_KEY_ID=${PROD_AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${PROD_AWS_SECRET_ACCESS_KEY}
    export AWS_ACCOUNT_ID=${PROD_ACCOUNT_ID}
    export DOMAIN_SUFFIX=
    export API_HOST=https://api.yanlin.cn/prefix-wechat-official-api
fi
if [ $GIT_BRANCH == "preprod" ]; then
    export ENV=preprod
    export CLUSTER_NAME=prod
    export AWS_ACCESS_KEY_ID=${PROD_AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${PROD_AWS_SECRET_ACCESS_KEY}
    export AWS_ACCOUNT_ID=${PROD_ACCOUNT_ID}
    export DOMAIN_SUFFIX=pre.
    export API_HOST=https://pre.api.yanlin.cn/prefix-wechat-official-api
fi
