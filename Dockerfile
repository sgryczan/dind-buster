FROM golang:1.23-bookworm

# Install docker, make, git, kubectl, helm
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      apt-transport-https \
      ca-certificates \
      gnupg2 \
      curl \
      tini \
      git \
      jq \
      make \
      kmod \
      procps && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y docker-ce && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/docker && \
    jq -n '{"experimental": true, "debug": true}' > /etc/docker/daemon.json

# Go 1.23 is already provided by the base image

RUN KIND_TMP_DIR=$(mktemp -d) && \
	cd $KIND_TMP_DIR && \
	go mod init tmp && \
	go install sigs.k8s.io/kind@v0.30.0 && \
	rm -rf $KIND_TMP_DIR && \
    kind version

# use iptables instead of nftables
RUN update-alternatives --set iptables  /usr/sbin/iptables-legacy || true && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true && \
    update-alternatives --set arptables /usr/sbin/arptables-legacy || true

# Set up subuid/subgid so that "--userns-remap=default" works
# out-of-the-box.
RUN set -x && \
    addgroup --system dockremap && \
    adduser --system --ingroup dockremap dockremap && \
    echo 'dockremap:165536:65536' >> /etc/subuid && \
    echo 'dockremap:165536:65536' >> /etc/subgid

VOLUME /var/lib/docker
VOLUME /var/log/docker
EXPOSE 2375 2376
ENV container=docker

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]