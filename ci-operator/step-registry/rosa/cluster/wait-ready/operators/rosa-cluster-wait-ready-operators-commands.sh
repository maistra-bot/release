#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

trap 'CHILDREN=$(jobs -p); if test -n "${CHILDREN}"; then kill ${CHILDREN} && wait; fi' TERM

function set_proxy () {
    if test -s "${SHARED_DIR}/proxy-conf.sh" ; then
        echo "setting the proxy"
        # cat "${SHARED_DIR}/proxy-conf.sh"
        echo "source ${SHARED_DIR}/proxy-conf.sh"
        source "${SHARED_DIR}/proxy-conf.sh"
    else
        echo "no proxy setting."
    fi
}
set_proxy

# Even the cluster is shown ready on ocm side, and the cluster operators are available, some of the cluster operators are
# still progressing. The ocp e2e test scenarios requires PROGRESSING=False for each cluster operator.
echo "Wait for cluster operators' progressing ready..."
CO_STATUS_LOG="${ARTIFACT_DIR}/co_status.log"
oc wait clusteroperators --all --for=condition=Progressing=false --timeout=30m > "${CO_STATUS_LOG}" 2>&1 || true
cat "${CO_STATUS_LOG}"

## If waiting operators timeout, call ocm-qe to analyze the root cause.
costatus=$(cat "${CO_STATUS_LOG}")
if [[ "${costatus}" =~ "timed out" ]]; then
  if [[ -e "${CLUSTER_PROFILE_DIR}/ocm-slack-hooks-url" ]]; then
    echo "Timeout: Meet operator issue. Sleep 3h to call debugging."
    CLUSTER_ID=$(cat "${SHARED_DIR}/cluster-id")
    slack_hook_url=$(cat "${CLUSTER_PROFILE_DIR}/ocm-slack-hooks-url")
    slack_message='{"text": "Timeout: Wait for the cluster '"${CLUSTER_ID}"' operators progressing ready. Sleep 3 hours for debugging. <@UD955LPJL> <@UEEQ10T4L>"}'
    curl -X POST -H 'Content-type: application/json' --data "${slack_message}" "${slack_hook_url}"
    sleep 10800
  fi

  exit 1
else
  echo "All cluster operators are done progressing."
fi
