import random
from locust import HttpUser, task, between, events


class ECommerceUser(HttpUser):
    """Simulates a normal browsing + purchasing user."""
    wait_time = between(0.5, 2.0)

    @task(5)
    def browse_products(self):
        self.client.get("/products", name="/products")

    @task(3)
    def view_single_product(self):
        product_id = random.randint(1, 5)
        self.client.get(f"/products/{product_id}", name="/products/{id}")

    @task(2)
    def create_order(self):
        self.client.post(
            "/orders",
            json={"product_id": random.randint(1, 5), "quantity": random.randint(1, 3)},
            name="/orders",
        )

    @task(1)
    def health_check(self):
        self.client.get("/health", name="/health")


class SpikeUser(HttpUser):
    """Simulates a traffic spike — used to trigger HPA and latency alerts."""
    wait_time = between(0.05, 0.2)
    weight = 1

    @task
    def hammer_products(self):
        self.client.get("/products", name="/products [spike]")


@events.request.add_listener
def on_request(request_type, name, response_time, response_length, response, **kwargs):
    if response is not None and response.status_code >= 500:
        print(f"[5xx] {request_type} {name} → {response.status_code} ({response_time:.0f}ms)")
