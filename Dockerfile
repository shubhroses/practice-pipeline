FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

# Run as non-root user for minimal security hygiene
RUN useradd -m appuser
USER appuser

CMD ["python", "app.py"]

