import os
basedir = os.path.abspath(os.path.dirname(__file__))

PRODUCT_BRAND_NAME = "Apla"
PRODUCT_NAME = "%s %s" % (PRODUCT_BRAND_NAME, "Block Explorer")

CSRF_ENABLED = True
SECRET_KEY = 'TWBt-1Cuz-GPtN-3vm2'

TIME_FORMAT = '%a, %d %b %Y %H:%M:%S'
CELERY_BROKER_URL = 'redis://localhost:6379/0'
CELERY_RESULT_BACKEND = 'redis://localhost:6379/0'

REDIS_URL = 'redis://localhost:6379/0'

SQLALCHEMY_TRACK_MODIFICATIONS = False

SQLALCHEMY_DATABASE_URI = 'sqlite:///tmp/genesis-blex/default.sqlite'
SQLALCHEMY_BINDS = {
}

ENABLE_DATABASE_EXPLORER = False
ENABLE_DATABASE_SELECTOR = True

DB_ENGINE_DISCOVERY_MAP = {
}

AUX_HELPERS_BIND_NAME = 'aux_genesis_helpers'

AUX_DB_ENGINE_DISCOVERY_MAP = {
}

SOCKETIO_HOST = '127.0.0.1'
SOCKETIO_PORT = 8000

FETCH_NUM_OF_BLOCKS = 50

BACKEND_API_URLS = {
}

BACKEND_VERSION_FEATURES_MAP = {
    '20180830': {
        'github-branch': 'master',
        'github-commmit': ' e5ddc76',
        'url': 'https://github.com/GenesisKernel/go-genesis/pull/513',
        'features': [
            'blocks_tx_info_api_endpoint',
            'system_parameters_at_ecosystem',
            'image_id_instead_of_avatar',
            'member_info_at_members',
            'keys_tables_delete_to_blocked',
        ]
    },
    '20180512': {
        'github-branch': 'develop',
        'github-commmit': '4b69b8e',
        'url': 'https://github.com/GenesisKernel/go-genesis/pull/290',
        'features': [
            'system_parameters_at_ecosystem',
            'image_id_instead_of_avatar',
            'member_info_at_members',
        ]
    }
}

DISKCACHE_PATH = '/tmp/genesis_block_explorer_diskcache'
DISKCACHE_DBEX_DATABASE_TIMEOUT = 10000

POSTS_PER_PAGE = 3
MAX_SEARCH_RESULTS = 50
