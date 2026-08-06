FROM almalinux:9

ARG UID=1000
ARG GID=1000
ARG TZ=UTC

# --- base packages ---
RUN dnf install -y epel-release \
 && dnf config-manager --set-enabled crb \
 && dnf install -y --allowerasing \
    git vim less curl wget jq rsync unzip zip tar make gcc which \
    screen htop strace lsof procps-ng \
    mariadb sqlite \
    python3 python3-pip python3-virtualenv \
    php-cli php-ldap php-mysqlnd php-pecl-xdebug php-xml php-mbstring \
    openldap-clients \
    bash-completion sudo shadow-utils tzdata \
 && dnf clean all

ENV TZ=${TZ}

# --- composer ---
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# --- phpunit --- (pinned to 9.6, the last major compatible with AlmaLinux 9's PHP 8.0)
RUN curl -sSL https://phar.phpunit.de/phpunit-9.6.phar -o /usr/local/bin/phpunit \
 && chmod +x /usr/local/bin/phpunit

# --- node (needed by most coding agent CLIs) ---
RUN dnf module enable -y nodejs:20 \
 && dnf install -y nodejs \
 && dnf clean all

# --- bun (needed by the claude-mem plugin's hook worker) ---
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash \
 && chmod +x /usr/local/bin/bun

# --- uv/uvx (needed by the claude-mem plugin's vector search) ---
RUN curl -fsSL https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# --- coding agent CLIs (installed regardless of per-project selection) ---
RUN npm install -g @anthropic-ai/claude-code \
 && npm install -g @openai/codex \
 && npm install -g @google/gemini-cli \
 && (curl -fsSL https://cursor.com/install | bash || true)

# GitHub CLI + Copilot extension
RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo \
 && dnf install -y gh \
 && dnf clean all

# --- coco user, configurable UID/GID ---
ARG HOME=/home/coco
# home dir is set to the host's own $HOME (see bin/coco / ARG HOME above),
# not /home/coco: at runtime the container is run with -e HOME=<host $HOME>
# so that agent configs cached with absolute host paths (e.g. claude's
# plugin marketplace install locations) stay valid. building the coco
# native binary (below) under that same path keeps `claude install` from
# needing to run again at every container start.
RUN (getent group "${GID}" >/dev/null || groupadd -g "${GID}" coco) \
 && (getent passwd "${UID}" >/dev/null || useradd -u "${UID}" -g "${GID}" -m -s /bin/bash -d "${HOME}" coco) \
 && echo "coco ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coco \
 && chmod 0440 /etc/sudoers.d/coco

# note: this gh CLI version ships `gh copilot` as a built-in command already,
# no separate extension install needed.

# claude-code manages its own native binary under ~/.local/bin, separate from
# the npm-installed shim above; bake it into the image now (as coco) so fresh
# --rm containers don't hit "missing or broken, run claude install to repair"
USER coco
RUN HOME="${HOME}" claude install
USER root

# --- shell / vim defaults ---
COPY container/bashrc.coco /etc/profile.d/coco-bashrc.sh
COPY container/vimrc /etc/vimrc.local
RUN echo 'source /etc/vimrc.local' >> /etc/vimrc

# --- entrypoint ---
COPY container/entrypoint.sh /usr/local/bin/coco-entrypoint.sh
RUN chmod +x /usr/local/bin/coco-entrypoint.sh

LABEL coco.hash=""
LABEL coco.version=""

USER coco
WORKDIR ${HOME}
ENTRYPOINT ["/usr/local/bin/coco-entrypoint.sh"]
CMD ["/bin/bash", "-l"]
