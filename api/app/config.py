import os


class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'default-secret-key')
    DATABASE_URL = os.environ.get('DATABASE_URL', 'sqlite:///app.db')
    AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
    ENVIRONMENT = os.environ.get('ENVIRONMENT', 'development')
    DEBUG = False
    TESTING = False


class DevelopmentConfig(Config):
    DEBUG = True
    ENVIRONMENT = 'development'


class TestingConfig(Config):
    TESTING = True
    ENVIRONMENT = 'testing'


class ProductionConfig(Config):
    ENVIRONMENT = 'production'
    DEBUG = False


config_by_name = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig
}
