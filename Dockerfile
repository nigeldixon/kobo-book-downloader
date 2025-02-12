FROM python:3.9-alpine AS builder
WORKDIR /opt/kobodl/src

ARG TARGETARCH
ENV PATH="/opt/kobodl/local/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/kobodl/local/venv"

RUN apk add --no-cache gcc libc-dev libffi-dev
ADD https://install.python-poetry.org /install-poetry.py
RUN POETRY_VERSION=1.6.1 POETRY_HOME=/opt/kobodl/local python /install-poetry.py

COPY . .

RUN poetry env use system
RUN poetry config virtualenvs.create false
RUN poetry debug resolve
RUN poetry install --no-dev

# Distributable Stage
FROM python:3.9-bookworm
WORKDIR /opt/kobodl/src

ENV PATH="/opt/kobodl/local/venv/bin:$PATH"

RUN apt-get update && apt-get -y install tini jq && \
  if [ -z ${CALIBRE_RELEASE+x} ]; then \
    CALIBRE_RELEASE=$(curl -sX GET "https://api.github.com/repos/kovidgoyal/calibre/releases/latest" \
    | jq -r .tag_name); \
  fi && \
  CALIBRE_VERSION="$(echo ${CALIBRE_RELEASE} | cut -c2-)" && \ 
  mkdir -p /app/calibre && \
  curl -o \
    /tmp/calibre.txz -L \
    "https://download.calibre-ebook.com/${CALIBRE_VERSION}/calibre-${CALIBRE_VERSION}-$(echo "$TARGETARCH" | sed "s/amd/x86_/").txz" && \
  tar xf \
    /tmp/calibre.txz \
    -C /app/calibre

COPY --from=builder /opt/kobodl /opt/kobodl

ENTRYPOINT ["/sbin/tini", "--", "kobodl"]
