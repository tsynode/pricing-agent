FROM python:3.12-slim

WORKDIR /app

# Copy requirements first for better caching
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ .

# Expose port for Streamlit
EXPOSE 8501

# Set environment variables
ENV PYTHONPATH=/app
ENV SESSION_BUCKET_NAME=pricing-agent-sessions
ENV PRICING_TABLE_NAME=pricing-rules
ENV INVENTORY_TABLE_NAME=inventory
ENV NAME_PREFIX=pricing-agent-dev
ENV AWS_REGION=us-east-1

# Run Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
