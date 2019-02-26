#!/bin/bash -e

### LIGHTTPD_CONF ##############################################################

# Lighttpd user, group and file owner
export LIGHTTPD_USER=lighttpd
export LIGHTTPD_GROUP=${LIGHTTPD_USER}

### DOCKER_LOG #################################################################

DOCKER_LOG_FILE_OWNER="${LIGHTTPD_USER}:${LIGHTTPD_GROUP}"
DOCKER_LOG_FILE="/var/log/docker.log"
DOCKER_ERR_FILE="/var/log/docker.err"

### DEFAULT_COMMAND ############################################################

# First arg is option (-o or --option)
if [ "${1:0:1}" = '-' -a -n "${DOCKER_COMMAND}" ]; then
  echo "Using default command ${DOCKER_COMMAND}"
	set -- ${DOCKER_COMMAND} "$@"
fi

# Command is not specified
if [[ ! $@ ]]; then
  echo "Using default command ${DOCKER_COMMAND}"
	set -- ${DOCKER_COMMAND}
fi

### DOCKER_LOG #################################################################

# Redirect logs to the Docker console
# - https://github.com/docker/docker/issues/6880#issuecomment-170214851
if [ ! -e "${DOCKER_LOG_FILE}" ]; then
  echo "Creating ${DOCKER_LOG_FILE}"
  mkfifo -m ${DOCKER_LOG_FILE_MODE:-600} ${DOCKER_LOG_FILE}
  chown ${DOCKER_LOG_FILE_OWNER} ${DOCKER_LOG_FILE}
  cat <> ${DOCKER_LOG_FILE} &
fi
if [ ! -e "${DOCKER_ERR_FILE}" ]; then
  echo "Creating ${DOCKER_ERR_FILE}"
  mkfifo -m ${DOCKER_LOG_FILE_MODE:-600} ${DOCKER_ERR_FILE}
  chown ${DOCKER_LOG_FILE_OWNER} ${DOCKER_ERR_FILE}
  cat <> ${DOCKER_ERR_FILE} 1>&2 &
fi

### EXEC_COMMAND ###############################################################

# Run as specified user
if [ -n "${DOCKER_USER}" ]; then
  set -- su-exec ${DOCKER_USER} "$@"
fi

# Exec command
echo "Executing command: $(printf "[%s]", "$@")"
exec "$@"

################################################################################
