import logging
import time
from datetime import datetime
from flask import Flask, jsonify

# Configure logging to show runtime behavior
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Track startup time for health checks
startup_time = time.time()

@app.route("/")
def hello():
    logger.info("Main endpoint accessed")
    return "Hello from Flask in k3s inside Vagrant!"

@app.route("/health")
def health_check():
    """Health check endpoint for Kubernetes probes"""
    uptime_seconds = time.time() - startup_time
    health_data = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime_seconds": round(uptime_seconds, 2),
        "service": "flask-demo",
        "version": "1.0.0"
    }
    logger.info(f"Health check requested - uptime: {uptime_seconds:.2f}s")
    return jsonify(health_data)

@app.route("/ready")
def readiness_check():
    """Readiness check - app is ready to receive traffic"""
    # Simple readiness check - in a real app, you'd check database connections, etc.
    if time.time() - startup_time > 5:  # Ready after 5 seconds
        logger.info("Readiness check: READY")
        return jsonify({"status": "ready", "message": "App is ready to receive traffic"}), 200
    else:
        logger.warning("Readiness check: NOT READY")
        return jsonify({"status": "not ready", "message": "App is not ready to receive traffic"}), 503

if __name__ == "__main__":
    logger.info("Starting Flask application...")
    logger.info(f"Startup time: {datetime.utcnow().isoformat()}")
    app.run(host="0.0.0.0", port=5000, debug=False)