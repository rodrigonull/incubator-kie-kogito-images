#!/usr/bin/env bash
# Parameters:
#   1 - image name - can't  be empty.
#   2 - git target branch - defaults to main
#   3 - git target uri - defaults to https://github.com/kiegroup/kogito-apps.git

# fast fail
set -e
set -o pipefail

KOGITO_APPS_REPO_NAME="kogito-apps"

# Read entries before sourcing
imageName="${1}"
gitBranch="${2:-main}"
gitUri="${3:-https://github.com/kiegroup/kogito-apps.git}"
contextDir=""
shift $#

echo ${imageName}
echo ${gitBranch}
echo ${gitUri}

script_dir_path=$(cd `dirname "${BASH_SOURCE[0]}"`; pwd -P)

MAVEN_OPTIONS="${MAVEN_OPTIONS} -Dquarkus.package.type=fast-jar -Dquarkus.build.image=false"

case ${imageName} in
    "kogito-management-console")
        contextDir="management-console"
        ;;
    "kogito-task-console")
        contextDir="task-console"
        ;;
    "kogito-data-index-ephemeral")
        contextDir="data-index/data-index-service/data-index-service-inmemory"
        ;;
    "kogito-data-index-infinispan")
        contextDir="data-index/data-index-service/data-index-service-infinispan"
        ;;
    "kogito-data-index-mongodb")
        contextDir="data-index/data-index-service/data-index-service-mongodb"
        ;;
    "kogito-data-index-oracle")
        contextDir="data-index/data-index-service/data-index-service-oracle"
        ;;
    "kogito-data-index-postgresql")
        contextDir="data-index/data-index-service/data-index-service-postgresql"
        ;;
    "kogito-jobs-service-ephemeral")
        contextDir="jobs-service/jobs-service-inmemory"
        ;;
    "kogito-jobs-service-infinispan")
        contextDir="jobs-service/jobs-service-infinispan"
        ;;
    "kogito-jobs-service-mongodb")
        contextDir="jobs-service/jobs-service-mongodb"
        ;;
    "kogito-jobs-service-postgresql")
        contextDir="jobs-service/jobs-service-postgresql"
        ;;
    "kogito-trusty-infinispan")
        contextDir="trusty/trusty-service/trusty-service-infinispan"
        ;;
    "kogito-trusty-postgresql")
        contextDir="trusty/trusty-service/trusty-service-postgresql"
        ;;
    "kogito-trusty-redis")
        contextDir="trusty/trusty-service/trusty-service-redis"
        ;;
    "kogito-trusty-ui")
        contextDir="trusty-ui"
        ;;
    "kogito-explainability")
        contextDir="explainability/explainability-service-messaging explainability/explainability-service-rest"
        ;;
    "kogito-jit-runner")
        contextDir="jitexecutor/jitexecutor-runner"
        ;;
    *)
        echo "${imageName} is not a supporting service image, exiting..."
        exit 0
        ;;
esac

for ctx in ${contextDir}; do
    target_tmp_dir="/tmp/build/$(basename ${ctx})"
    build_target_dir="/tmp/$(basename ${ctx})"
    rm -rf ${target_tmp_dir} && mkdir -p ${target_tmp_dir}
    rm -rf ${build_target_dir} && mkdir -p ${build_target_dir}

    . ${script_dir_path}/setup-maven.sh "${build_target_dir}"/settings.xml

    cd ${build_target_dir}
    echo "Using branch/tag ${gitBranch}, checking out. Temporary build dir is ${build_target_dir} and target dis is ${target_tmp_dir}"

    if [ ! -d "${build_target_dir}/${KOGITO_APPS_REPO_NAME}" ]; then
        git_command="git clone --single-branch --branch ${gitBranch} --depth 1 ${gitUri}"
        echo "cloning ${KOGITO_APPS_REPO_NAME} with the following git command: ${git_command}"
        eval ${git_command}
    fi
    cd ${KOGITO_APPS_REPO_NAME} && echo "working dir `pwd`"
    mvn_command="mvn -am -pl ${ctx} package ${MAVEN_OPTIONS} -Dmaven.repo.local=/tmp/temp_maven/${ctx}"
    echo "Building component(s) ${contextDir} with the following maven command [${mvn_command}]"
    export YARN_CACHE_FOLDER=/tmp/cache/yarn/${ctx} # Fix for building yarn apps in parallel
    export CYPRESS_CACHE_FOLDER=/tmp/cache/cypress/${ctx} # https://docs.cypress.io/guides/getting-started/installing-cypress#Advanced
    eval ${mvn_command}
    cd ${ctx}/target/
    zip -r $(basename ${ctx})-quarkus-app.zip quarkus-app
    cp -v $(basename ${ctx})-quarkus-app.zip ${target_tmp_dir}/
    cd -
done