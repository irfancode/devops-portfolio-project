import os
import time
import uuid
from flask import Blueprint, request, jsonify
from app import REQUEST_LATENCY
import structlog

logger = structlog.get_logger()

main = Blueprint('main', __name__)

IN_MEMORY_DB = {}


@main.before_request
def before_request():
    request.start_time = time.time()


@main.route('/api/v1/items', methods=['GET'])
def get_items():
    start = time.time()
    items = list(IN_MEMORY_DB.values())
    REQUEST_LATENCY.labels(method='GET', endpoint='/api/v1/items').observe(time.time() - start)
    return jsonify({'items': items, 'count': len(items)}), 200


@main.route('/api/v1/items', methods=['POST'])
def create_item():
    start = time.time()
    data = request.get_json()

    if not data or 'name' not in data:
        return jsonify({'error': 'Name is required'}), 400

    item_id = str(uuid.uuid4())
    item = {
        'id': item_id,
        'name': data['name'],
        'description': data.get('description', ''),
        'status': data.get('status', 'active'),
        'created_at': time.time()
    }
    IN_MEMORY_DB[item_id] = item

    REQUEST_LATENCY.labels(method='POST', endpoint='/api/v1/items').observe(time.time() - start)
    logger.info('item_created', item_id=item_id)
    return jsonify(item), 201


@main.route('/api/v1/items/<item_id>', methods=['GET'])
def get_item(item_id):
    start = time.time()
    item = IN_MEMORY_DB.get(item_id)

    if not item:
        return jsonify({'error': 'Item not found'}), 404

    REQUEST_LATENCY.labels(method='GET', endpoint='/api/v1/items/<item_id>').observe(time.time() - start)
    return jsonify(item), 200


@main.route('/api/v1/items/<item_id>', methods=['PUT'])
def update_item(item_id):
    start = time.time()
    item = IN_MEMORY_DB.get(item_id)

    if not item:
        return jsonify({'error': 'Item not found'}), 404

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    item['name'] = data.get('name', item['name'])
    item['description'] = data.get('description', item['description'])
    item['status'] = data.get('status', item['status'])
    item['updated_at'] = time.time()

    REQUEST_LATENCY.labels(method='PUT', endpoint='/api/v1/items/<item_id>').observe(time.time() - start)
    logger.info('item_updated', item_id=item_id)
    return jsonify(item), 200


@main.route('/api/v1/items/<item_id>', methods=['DELETE'])
def delete_item(item_id):
    start = time.time()
    item = IN_MEMORY_DB.pop(item_id, None)

    if not item:
        return jsonify({'error': 'Item not found'}), 404

    REQUEST_LATENCY.labels(method='DELETE', endpoint='/api/v1/items/<item_id>').observe(time.time() - start)
    logger.info('item_deleted', item_id=item_id)
    return jsonify({'message': 'Item deleted successfully'}), 200


@main.route('/api/v1/stats', methods=['GET'])
def get_stats():
    start = time.time()
    stats = {
        'total_items': len(IN_MEMORY_DB),
        'active_items': sum(1 for i in IN_MEMORY_DB.values() if i.get('status') == 'active'),
        'environment': os.environ.get('ENVIRONMENT', 'development'),
        'uptime': time.time()
    }
    REQUEST_LATENCY.labels(method='GET', endpoint='/api/v1/stats').observe(time.time() - start)
    return jsonify(stats), 200
