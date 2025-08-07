FROM python:3.11-slim

# Security: Use specific version and minimal base image
LABEL maintainer="shubhrose.singh@email.com"
LABEL security.scan="enabled"

WORKDIR /app

# Security: Install security updates and remove package manager cache
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Security: Copy only required files
COPY requirements.txt .

# Security: Pin dependencies and use trusted index
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Security: Create non-root user with minimal privileges
RUN useradd -m -u 1001 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Security: Use non-privileged port
EXPOSE 5000

# Security: Run with minimal capabilities
CMD ["python", "app.py"]