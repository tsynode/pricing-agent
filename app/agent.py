"""
Pricing Agent using Strands Agents SDK
"""
from strands import Agent
from strands.models import BedrockModel
from strands_tools import retrieve, current_time
import boto3
import os
import json

# Direct imports for Docker container environment
from tools.pricing import check_price_compliance, update_price, get_pricing_policy
from tools.inventory import scan_inventory

def get_knowledge_base_id():
    """Retrieve the knowledge base ID from SSM Parameter Store"""
    ssm = boto3.client('ssm')
    name_prefix = os.environ.get('NAME_PREFIX', 'pricing-agent-dev')
    
    try:
        response = ssm.get_parameter(
            Name=f"/{name_prefix}/knowledge-base-id",
            WithDecryption=False
        )
        return response['Parameter']['Value']
    except Exception as e:
        print(f"Error retrieving knowledge base ID: {str(e)}")
        return None

def create_agent(session_id=None):
    """Create the pricing agent with optional session restoration"""
    
    # Define the system prompt
    system_prompt = """You are a pricing compliance agent that helps ensure products are priced correctly
    according to company policies and regulations. You can:
    
    1. Scan inventory data to identify pricing issues
    2. Check if a specific product's price complies with policies
    3. Explain pricing policies to users by retrieving them from the knowledge base
    4. Update prices when authorized
    
    Always be helpful, clear, and accurate in your responses. When explaining pricing policies,
    make sure to refer to the specific policy documents in the knowledge base.
    """
    
    # Get knowledge base ID from SSM Parameter Store
    kb_id = get_knowledge_base_id()
    
    # Configure the retrieve tool with the knowledge base
    retrieve_config = {
        "knowledge_base_id": kb_id,
        "model_id": "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
        "region_name": os.environ.get('AWS_REGION', 'us-east-1')
    }
    
    # Create the agent with Claude 3 Sonnet
    agent = Agent(
        model=BedrockModel(
            model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0",
            max_tokens=4096
        ),
        system_prompt=system_prompt,
        tools=[
            # Built-in tools with configuration
            {"tool": retrieve, "config": retrieve_config},
            current_time,
            
            # Custom pricing tools
            check_price_compliance,
            scan_inventory,
            update_price,
            get_pricing_policy
        ]
    )
    
    # Restore session if provided
    if session_id:
        try:
            # Get S3 bucket name from environment
            bucket_name = os.environ.get('SESSION_BUCKET_NAME')
            
            if bucket_name:
                # Initialize S3 client
                s3 = boto3.client('s3')
                
                # Try to get session data
                response = s3.get_object(
                    Bucket=bucket_name,
                    Key=f"sessions/{session_id}.json"
                )
                
                # Parse session data
                session_data = json.loads(response['Body'].read().decode('utf-8'))
                
                # Restore messages to agent
                if 'messages' in session_data:
                    agent.messages = session_data['messages']
        except Exception as e:
            print(f"Error restoring session: {str(e)}")
            # If any error occurs, just use a new session
            pass
    
    return agent

def save_agent_session(agent, session_id):
    """Save the agent session to S3 for persistence"""
    try:
        # Get S3 bucket name from environment
        bucket_name = os.environ.get('SESSION_BUCKET_NAME')
        
        if bucket_name and session_id:
            # Initialize S3 client
            s3 = boto3.client('s3')
            
            # Prepare session data
            session_data = {
                "messages": agent.messages
            }
            
            # Save to S3
            s3.put_object(
                Bucket=bucket_name,
                Key=f"sessions/{session_id}.json",
                Body=json.dumps(session_data),
                ContentType="application/json"
            )
            
            return True
    except Exception as e:
        print(f"Error saving session: {str(e)}")
        return False
    
    return False
