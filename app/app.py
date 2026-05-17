import time
import random
from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

ACTIVE_REQUESTS = Gauge(
    'http_active_requests',
    'Number of currently active HTTP requests'
)

PRODUCTS = [
    {"id": 1, "name": "Laptop",     "price": 999.99, "stock": 50},
    {"id": 2, "name": "Phone",      "price": 499.99, "stock": 100},
    {"id": 3, "name": "Tablet",     "price": 299.99, "stock": 75},
    {"id": 4, "name": "Headphones", "price": 149.99, "stock": 200},
    {"id": 5, "name": "Monitor",    "price": 349.99, "stock": 30},
]


@app.before_request
def before_request():
    request.start_time = time.time()
    ACTIVE_REQUESTS.inc()


@app.after_request
def after_request(response):
    latency = time.time() - request.start_time
    REQUEST_LATENCY.labels(method=request.method, endpoint=request.path).observe(latency)
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.path,
        status=str(response.status_code)
    ).inc()
    ACTIVE_REQUESTS.dec()
    return response


@app.route('/')
def index():
    return jsonify({"service": "sre-ecommerce", "version": "1.0.0", "status": "ok"})


@app.route('/health')
def health():
    return jsonify({"status": "healthy"})


@app.route('/ready')
def ready():
    return jsonify({"status": "ready"})


@app.route('/products')
def get_products():
    if random.random() < 0.05:
        time.sleep(0.6)
    return jsonify({"products": PRODUCTS, "total": len(PRODUCTS)})


@app.route('/products/<int:product_id>')
def get_product(product_id):
    product = next((p for p in PRODUCTS if p["id"] == product_id), None)
    if not product:
        return jsonify({"error": "Product not found"}), 404
    return jsonify(product)


@app.route('/orders', methods=['POST'])
def create_order():
    data = request.get_json()
    if not data or 'product_id' not in data:
        return jsonify({"error": "product_id required"}), 400

    product = next((p for p in PRODUCTS if p["id"] == data['product_id']), None)
    if not product:
        return jsonify({"error": "Product not found"}), 404

    time.sleep(random.uniform(0.01, 0.1))

    order = {
        "order_id": random.randint(10000, 99999),
        "product": product["name"],
        "quantity": data.get('quantity', 1),
        "total": product["price"] * data.get('quantity', 1),
        "status": "confirmed",
    }
    return jsonify(order), 201


@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
