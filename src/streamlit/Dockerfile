FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

# Add a health check endpoint for the ALB
RUN echo '#!/bin/bash\ncurl -f http://localhost:8501/healthz || exit 1' > /app/healthcheck.sh && \
    chmod +x /app/healthcheck.sh

EXPOSE 8501

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 CMD [ "/app/healthcheck.sh" ]

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
