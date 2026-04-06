import pytest
from app import create_app
from app.config import TestingConfig


@pytest.fixture
def client():
    app = create_app(TestingConfig)
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_health_check(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'


def test_metrics_endpoint(client):
    response = client.get('/metrics')
    assert response.status_code == 200


def test_create_item(client):
    response = client.post('/api/v1/items', json={
        'name': 'Test Item',
        'description': 'A test item',
        'status': 'active'
    })
    assert response.status_code == 201
    data = response.get_json()
    assert data['name'] == 'Test Item'
    assert 'id' in data


def test_create_item_missing_name(client):
    response = client.post('/api/v1/items', json={'description': 'No name'})
    assert response.status_code == 400


def test_get_items_empty(client):
    response = client.get('/api/v1/items')
    assert response.status_code == 200
    data = response.get_json()
    assert data['count'] == 0
    assert data['items'] == []


def test_get_item_not_found(client):
    response = client.get('/api/v1/items/nonexistent-id')
    assert response.status_code == 404


def test_update_item(client):
    create_resp = client.post('/api/v1/items', json={'name': 'Original'})
    item_id = create_resp.get_json()['id']

    response = client.put(f'/api/v1/items/{item_id}', json={'name': 'Updated'})
    assert response.status_code == 200
    assert response.get_json()['name'] == 'Updated'


def test_delete_item(client):
    create_resp = client.post('/api/v1/items', json={'name': 'To Delete'})
    item_id = create_resp.get_json()['id']

    response = client.delete(f'/api/v1/items/{item_id}')
    assert response.status_code == 200

    response = client.get(f'/api/v1/items/{item_id}')
    assert response.status_code == 404


def test_get_stats(client):
    client.post('/api/v1/items', json={'name': 'Item 1'})
    client.post('/api/v1/items', json={'name': 'Item 2', 'status': 'active'})

    response = client.get('/api/v1/stats')
    assert response.status_code == 200
    data = response.get_json()
    assert data['total_items'] == 2
    assert data['active_items'] == 2
