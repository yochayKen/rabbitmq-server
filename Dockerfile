FROM debian:10

ARG FAIL_FAST_VERBOSE="set -ex"
ENV DEBIAN_FRONTEND=noninteractive
ARG PKG_INSTALL="apt-get install --yes"

# Use the terminal with 256 colors support
ENV TERM=xterm-256color

RUN echo "Pre-warm package manager cache..." \
    ; ${FAIL_FAST_VERBOSE} \
    ; apt-get update

RUN echo "Install openssl..." \
    ; ${FAIL_FAST_VERBOSE} \
    ; ${PKG_INSTALL} openssl \
    ; openssl version

ARG RABBITMQ_INSTALL_DIR=/opt/rabbitmq
RUN mkdir -p ${RABBITMQ_INSTALL_DIR}/log
ARG RABBITMQ_VERSION
ADD _rel/RabbitMQ/RabbitMQ-${RABBITMQ_VERSION}.tar.gz ${RABBITMQ_INSTALL_DIR}
WORKDIR ${RABBITMQ_INSTALL_DIR}

# TODO: do not hardcode ERTS version
ENV PATH=${RABBITMQ_INSTALL_DIR}/bin:${RABBITMQ_INSTALL_DIR}/erts-12.0/bin/:$PATH

ARG RABBITMQ_DATA_DIR=${RABBITMQ_INSTALL_DIR}/var/lib/rabbitmq
ARG RABBITMQ_CONF_DIR=${RABBITMQ_INSTALL_DIR}/etc/rabbitmq
ARG RABBITMQ_LOG_DIR=${RABBITMQ_INSTALL_DIR}/var/log/rabbitmq

# Hint that this should be a volume
VOLUME ${RABBITMQ_DATA_DIR}

RUN echo "Configure rabbitmq system user & group..." \
    ; ${FAIL_FAST_VERBOSE} \
    ; groupadd --gid 999 --system rabbitmq \
    ; useradd --uid 999 --system --home-dir ${RABBITMQ_DATA_DIR} --gid rabbitmq rabbitmq \
    ; id rabbitmq \
    ; mkdir -p ${RABBITMQ_DATA_DIR} ${RABBITMQ_CONF_DIR} ${RABBITMQ_LOG_DIR} \
    ; chown -fR rabbitmq:rabbitmq ${RABBITMQ_DATA_DIR} ${RABBITMQ_CONF_DIR} ${RABBITMQ_LOG_DIR} ${RABBITMQ_INSTALL_DIR}/log \
    ; chmod 770 ${RABBITMQ_DATA_DIR} ${RABBITMQ_CONF_DIR} ${RABBITMQ_LOG_DIR} ${RABBITMQ_INSTALL_DIR}/log

# Configure locale
ARG LOCALE=C.UTF-8
ENV LC_ALL=${LOCALE} LC_CTYPE=${LOCALE} LANG=${LOCALE} LANGUAGE=${LOCALE}

CMD ["RabbitMQ", "console"]
# https://www.rabbitmq.com/networking.html
EXPOSE 1883 4369 5671 5672 8883 15674 15675 25672 61613 61614

# Last command as root...
RUN echo "Install *lightweight* utilities for system monitoring..." \
    ; ${FAIL_FAST_VERBOSE} \
    ; ${PKG_INSTALL} atop htop nmon sysstat iperf3 fping \
    ; echo "Cleanup apt package lists..." \
    ; rm -fr /var/lib/apt/lists/*

# Run all following commands as the rabbitmq user
USER rabbitmq

RUN echo "Enable plugins..." \
    ; echo "[rabbitmq_prometheus, rabbitmq_management]." > ${RABBITMQ_CONF_DIR}/enabled_plugins
EXPOSE 15691 15692
EXPOSE 15671 15672

RUN echo "Allow guest user to login from anywhere..." \
    ; ${FAIL_FAST_VERBOSE} \
    ; mkdir -p ${RABBITMQ_CONF_DIR}/conf.d \
    ; echo "loopback_users = none" > ${RABBITMQ_CONF_DIR}/conf.d/loopback_users.conf

RUN echo "Enable debug logging with non-truncated types to STDOUT & STDERR..." \
    ; ${FAIL_FAST_VERBOSE} \
    ; mkdir -p ${RABBITMQ_CONF_DIR}/conf.d \
    ; echo "log.console.level = debug" > ${RABBITMQ_CONF_DIR}/conf.d/debug_logging.conf \
    ; echo "log.console.formatter.level_format = lc" >> ${RABBITMQ_CONF_DIR}/conf.d/debug_logging.conf

RUN echo "Remove Erlang cookie so that we start with a clean slate..." \
    ; ${FAIL_FAST_VERBOSE} \
    ; rm -f ${RABBITMQ_DATA_DIR}/.erlang.cookie
