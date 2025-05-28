"""
Pricing Agent using Strands Agents SDK
"""
from strands import Agent
from strands.models import BedrockModel
from strands_tools import retrieve, current_time
import boto3
import os
import json
from datetime import datetime

# Direct imports for Docker container environment
from tools.pricing import check_price_compliance, update_price, get_pricing_policy
from tools.inventory import scan_inventory

def get_knowledge_base_id():
    """Retrieve the knowledge base ID from SSM Parameter Store"""
    ssm = boto3.client('ssm')
    
    # Get knowledge base parameter path from environment or use default
    knowledge_base_param_path = os.environ.get('KB_PARAM_NAME', '/pricing-agent-dev/knowledge-base-id')
    
    try:
        response = ssm.get_parameter(
            Name=knowledge_base_param_path,
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
        "model_id": os.environ.get('MODEL_ID', 'anthropic.claude-opus-4-20250514-v1:0'),
        "region_name": os.environ.get('AWS_REGION', 'us-east-1')
    }
    
    # Use Claude 3 Haiku which supports on-demand throughput
    # This model doesn't require provisioned throughput
    print(f"Environment MODEL_ID: {os.environ.get('MODEL_ID', 'Not set')}")
    print(f"All environment variables: {dict(os.environ)}")
    
    # Force the model to be Claude 3 Haiku regardless of environment variable
    model_id = 'anthropic.claude-3-haiku-20240307-v1:0'
    model_identifier = model_id
    print(f"Using model: {model_identifier}")
    
    # Create the agent with the configured model
    agent = Agent(
        model=BedrockModel(
            model_id=model_identifier,
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
    
    # Try to restore session from DynamoDB if session_id is provided
    if session_id:
        try:
            # Get the DynamoDB table name from environment or use default
            table_name = os.environ.get('SESSION_TABLE_NAME', 'pricing-agent-sessions')
            
            # Initialize DynamoDB client and table
            dynamodb = boto3.resource('dynamodb')
            session_table = dynamodb.Table(table_name)
            
            # Try to get session data
            response = session_table.get_item(Key={'session_id': session_id})
            
            if 'Item' in response:
                # Parse session data
                session_data = response['Item']
                messages = json.loads(session_data.get('messages', '[]'))
                
                # Restore messages to agent
                if messages:
                    agent.messages = messages
                    print(f"Restored session {session_id} with {len(messages)} messages")
                else:
                    print(f"Session {session_id} exists but has no messages")
            else:
                print(f"Creating new session with ID: {session_id}")
        except Exception as e:
            print(f"Error restoring session from DynamoDB: {str(e)}")
            print(f"Proceeding with new session: {session_id}")
    
    return agent

def get_chat_list():
    """Get a list of previous chat sessions from DynamoDB
    
    Returns:
        list: List of chat sessions with session_id, last_updated, and first message
    """
    try:
        # Get the DynamoDB table name from environment or use default
        table_name = os.environ.get('SESSION_TABLE_NAME', 'pricing-agent-sessions')
        
        # Initialize DynamoDB client and table
        dynamodb = boto3.resource('dynamodb')
        session_table = dynamodb.Table(table_name)
        
        # Scan for all sessions, sorted by last_updated
        response = session_table.scan()
        sessions = response.get('Items', [])
        
        # Process sessions to extract relevant information
        chat_list = []
        for session in sessions:
            session_id = session.get('session_id')
            last_updated = session.get('last_updated')
            messages_json = session.get('messages', '[]')
            
            try:
                messages = json.loads(messages_json)
                # Find the first user message to use as a title
                chat_title = "New Chat"
                for msg in messages:
                    if msg.get('role') == 'user':
                        # Truncate long messages for the title
                        content = msg.get('content', '')
                        chat_title = content[:30] + "..." if len(content) > 30 else content
                        break
                
                chat_list.append({
                    'session_id': session_id,
                    'last_updated': last_updated,
                    'title': chat_title
                })
            except json.JSONDecodeError:
                # Skip sessions with invalid message format
                continue
        
        # Sort by last_updated (newest first)
        chat_list.sort(key=lambda x: x.get('last_updated', ''), reverse=True)
        
        return chat_list
    except Exception as e:
        print(f"Error retrieving chat list: {str(e)}")
        return []

def save_agent_session(agent, session_id):
    """Save the agent session state to DynamoDB
    
    Persists the agent's message history to DynamoDB for session continuity
    across application restarts and multiple instances.
    
    Args:
        agent: The Strands Agent instance to save
        session_id: Unique identifier for the user session
        
    Returns:
        bool: True if session was saved successfully, False otherwise
    """
    try:
        # Get the DynamoDB table name from environment or use default
        table_name = os.environ.get('SESSION_TABLE_NAME', 'pricing-agent-sessions')
        
        # Initialize DynamoDB client and table
        dynamodb = boto3.resource('dynamodb')
        session_table = dynamodb.Table(table_name)
        
        # Prepare session data
        session_data = {
            'session_id': session_id,
            'messages': json.dumps(agent.messages),
            'last_updated': datetime.now().isoformat(),
            'ttl': int((datetime.now().timestamp() + (30 * 24 * 60 * 60)))  # 30 days TTL
        }
        
        # Save to DynamoDB
        session_table.put_item(Item=session_data)
        
        print(f"Session {session_id} saved to DynamoDB")
        return True
    except Exception as e:
        print(f"Error saving session to DynamoDB: {str(e)}")
        return False
