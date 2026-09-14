from flask import Flask, jsonify
import socket
import os

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "message": "Hello from EKS!",
        "hostname": socket.gethostname(),
        "version": os.environ.get("APP_VERSION", "v1")
    })

@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
# small change to trigger pipeline
