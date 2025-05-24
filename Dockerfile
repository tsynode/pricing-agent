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
ENV PRICING_TABLE_NAME=pricing-rules
ENV INVENTORY_TABLE_NAME=inventory
ENV SESSION_TABLE_NAME=pricing-agent-sessions
ENV NAME_PREFIX=pricing-agent-dev
ENV AWS_REGION=us-east-1
ENV POLICY_BUCKET_NAME=pricing-agent-dev-policies
# The knowledge base ID will be retrieved from SSM Parameter Store
ENV KB_PARAM_NAME=/pricing-agent-dev/knowledge-base-id
# Default model ID (can be overridden at runtime)
ENV MODEL_ID=anthropic.claude-opus-4-20250514-v1:0

# Run Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
