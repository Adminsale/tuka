import time
import os
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

OUT = r"C:\Users\shado\GitHub\tuka\screenshots"
os.makedirs(OUT, exist_ok=True)

opts = Options()
opts.add_argument("--headless")
opts.add_argument("--no-sandbox")
opts.add_argument("--disable-dev-shm-usage")
opts.add_argument("--window-size=1600,900")

d = webdriver.Chrome(options=opts)
wait = WebDriverWait(d, 15)


def shot(name, url, wait_sec=2, scroll_y=0):
    print(f"[screenshot] {name}")
    d.get(url)
    time.sleep(wait_sec)
    if scroll_y:
        d.execute_script(f"window.scrollTo(0, {scroll_y});")
        time.sleep(1.5)
    path = os.path.join(OUT, f"{name}.png")
    d.save_screenshot(path)
    print(f"  saved: {path}")


# ── Prometheus ────────────────────────────────────────────────────────────────
shot("01_prometheus_home",    "http://localhost:9090",         2)
shot("02_prometheus_alerts",  "http://localhost:9090/alerts",  2)
shot("03_prometheus_targets", "http://localhost:9090/targets", 2)

# Graph with PromQL
d.get("http://localhost:9090/graph")
time.sleep(3)
try:
    cm = d.find_element(By.CSS_SELECTOR, ".cm-content")
    cm.clear()
    cm.send_keys("rate(http_requests_total[1m])")
    d.find_element(By.CSS_SELECTOR, "button[type=submit]").click()
    time.sleep(4)
except Exception as e:
    print(f"  (PromQL skip: {e})")
d.save_screenshot(os.path.join(OUT, "04_prometheus_graph.png"))
print("  saved: 04_prometheus_graph.png")

# ── Alertmanager ──────────────────────────────────────────────────────────────
shot("05_alertmanager", "http://localhost:9093", 3)

# ── Grafana login ─────────────────────────────────────────────────────────────
d.get("http://localhost:3000/login")
time.sleep(3)
try:
    d.find_element(By.NAME, "user").send_keys("admin")
    d.find_element(By.NAME, "password").send_keys("admin123")
    d.find_element(By.CSS_SELECTOR, "button[type=submit]").click()
    time.sleep(3)
except Exception as e:
    print(f"  (login: {e})")

shot("06_grafana_home",             "http://localhost:3000",             3)
shot("07_grafana_dashboard_top",    "http://localhost:3000/d/sre-sli-slo", 6, scroll_y=0)
shot("08_grafana_dashboard_mid",    "http://localhost:3000/d/sre-sli-slo", 5, scroll_y=500)
shot("09_grafana_dashboard_bottom", "http://localhost:3000/d/sre-sli-slo", 5, scroll_y=1100)

# ── App API & Metrics ─────────────────────────────────────────────────────────
shot("10_app_products_api", "http://localhost:5000/products", 1)
shot("11_app_metrics_raw",  "http://localhost:5000/metrics",  1)

d.quit()
print("All done.")
