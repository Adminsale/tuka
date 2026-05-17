import pytest
from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config['TESTING'] = True
    with flask_app.test_client() as client:
        yield client


def test_health(client):
    r = client.get('/health')
    assert r.status_code == 200
    assert r.get_json()['status'] == 'healthy'


def test_ready(client):
    assert client.get('/ready').status_code == 200


def test_index(client):
    data = client.get('/').get_json()
    assert data['service'] == 'sre-ecommerce'


def test_get_products(client):
    r = client.get('/products')
    assert r.status_code == 200
    assert len(r.get_json()['products']) > 0


def test_get_product(client):
    assert client.get('/products/1').status_code == 200


def test_get_product_not_found(client):
    assert client.get('/products/999').status_code == 404


def test_create_order(client):
    r = client.post('/orders', json={'product_id': 1, 'quantity': 2})
    assert r.status_code == 201
    assert 'order_id' in r.get_json()


def test_create_order_no_body(client):
    assert client.post('/orders', json={}).status_code == 400


def test_metrics_endpoint(client):
    r = client.get('/metrics')
    assert r.status_code == 200
    assert b'http_requests_total' in r.data
