FROM python:3.12-slim-bookworm
ARG APP_VERSION=1.0.0
ENV PYTHONUNBUFFERED=1 APP_VERSION=${APP_VERSION}
WORKDIR /app
RUN useradd --uid 10001 --create-home app
COPY app/app.py .
USER app
EXPOSE 5000
CMD ["python", "app.py"]
