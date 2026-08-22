FROM python:3.14.7-alpine3.24

ARG APP_VERSION=dev

LABEL org.opencontainers.image.title="TaskFlow API" \
      org.opencontainers.image.description="API acadêmica para demonstração de CI/CD" \
      org.opencontainers.image.source="https://github.com/Gruiiz/taskflow-devops" \
      org.opencontainers.image.version="${APP_VERSION}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    APP_VERSION=${APP_VERSION} \
    LOG_LEVEL=INFO

WORKDIR /app

RUN addgroup -S taskflow \
    && adduser -S -G taskflow taskflow

COPY --chown=taskflow:taskflow app ./app

USER taskflow
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

STOPSIGNAL SIGTERM

CMD ["python", "-m", "app.main", "--host", "0.0.0.0", "--port", "8000"]
