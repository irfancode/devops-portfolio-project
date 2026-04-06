import os
from flask import Flask
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from flask import Response
import structlog

REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint']
)

logger = structlog.get_logger()


def create_app(config_class=None):
    app = Flask(__name__)

    if config_class:
        app.config.from_object(config_class)
    else:
        app.config.from_mapping(
            SECRET_KEY=os.environ.get('SECRET_KEY', 'dev-secret-key'),
            DATABASE_URL=os.environ.get('DATABASE_URL', 'sqlite:///app.db'),
            AWS_REGION=os.environ.get('AWS_REGION', 'us-east-1'),
            ENVIRONMENT=os.environ.get('ENVIRONMENT', 'development')
        )

    from app.routes import main
    app.register_blueprint(main)

    @app.route('/health')
    def health():
        return {'status': 'healthy', 'environment': app.config.get('ENVIRONMENT', 'development')}

    @app.route('/metrics')
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    @app.after_request
    def after_request(response):
        REQUEST_COUNT.labels(
            method=response.request.method,
            endpoint=response.request.path,
            status=response.status_code
        ).inc()
        logger.info(
            'http_request',
            method=response.request.method,
            path=response.request.path,
            status=response.status_code,
            duration=getattr(response.request, 'duration', 0)
        )
        return response

    return app


if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True)
