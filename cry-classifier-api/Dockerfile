# Cry Classification API Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for librosa
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Copy ONNX model and class labels (if available)
RUN mkdir -p models
COPY models/ models/

# Expose port
EXPOSE 8000

# Run the application
CMD ["python", "main.py"]
