import json
import os
import logging
import boto3
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

# Environment variables
BEDROCK_AGENT_ID = os.environ.get('BEDROCK_AGENT_ID')
BEDROCK_AGENT_ALIAS_ID = os.environ.get('BEDROCK_AGENT_ALIAS_ID')

def lambda_handler(event, context):
    """
    Bridges SQS messages to Bedrock Agent
    
    Input: SQS event with Records array
    Each record.body contains: {"batch_id": "...", "item_ids": [...]}
    
    Functionality:
    - Parse SQS message batches
    - Create formatted prompts for Bedrock Agent
    - Invoke Bedrock Agent with batch assessment request
    - Handle agent responses and errors
    - Mark SQS messages as processed
    """
    logger.info(f"Received SQS event with {len(event.get('Records', []))} records")
    
    results = []
    
    for record in event.get('Records', []):
        try:
            # Parse the SQS message
            message_body = json.loads(record.get('body', '{}'))
            batch_id = message_body.get('batch_id')
            item_ids = message_body.get('item_ids', [])
            
            logger.info(f"Processing batch {batch_id} with {len(item_ids)} items")
            
            # Create prompt for Bedrock Agent
            prompt = create_agent_prompt(batch_id, item_ids)
            
            # Invoke Bedrock Agent
            response = invoke_bedrock_agent(prompt)
            
            # Process and log agent response
            process_agent_response(response, batch_id)
            
            results.append({
                'batch_id': batch_id,
                'status': 'processed',
                'items_count': len(item_ids)
            })
            
        except Exception as e:
            logger.error(f"Error processing SQS message: {str(e)}")
            # Do not raise the exception to allow other messages to be processed
            # The failed message will be retried based on SQS visibility timeout
            results.append({
                'batch_id': message_body.get('batch_id', 'unknown'),
                'status': 'error',
                'error': str(e)
            })
    
    return {
        'processed_batches': len(results),
        'results': results
    }

def create_agent_prompt(batch_id, item_ids):
    """
    Create a formatted prompt for the Bedrock Agent
    """
    # Limit the number of item IDs in the prompt to avoid token limits
    max_items_in_prompt = 50
    truncated_items = item_ids[:max_items_in_prompt]
    
    if len(item_ids) > max_items_in_prompt:
        item_list = ", ".join(truncated_items) + f" and {len(item_ids) - max_items_in_prompt} more items"
    else:
        item_list = ", ".join(item_ids)
    
    prompt = f"""
    Assess pricing compliance for the following batch of items: {item_list}.
    
    For each item:
    1. Retrieve the current price and details using get_item_price()
    2. Check the pricing policies in the knowledge base that apply to this item
    3. Determine if the current price is compliant with all applicable policies
    4. If non-compliant, calculate the correct price and update it using update_price()
    5. Provide a summary of all changes made and the reasoning
    
    This is batch {batch_id} with {len(item_ids)} items total.
    """
    
    return prompt

def invoke_bedrock_agent(prompt):
    """
    Invoke the Bedrock Agent with the given prompt
    """
    try:
        response = bedrock_agent_runtime.invoke_agent(
            agentId=BEDROCK_AGENT_ID,
            agentAliasId=BEDROCK_AGENT_ALIAS_ID,
            sessionId=f"pricing-compliance-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
            inputText=prompt
        )
        
        # Extract the agent's response
        response_stream = response.get('completion')
        response_text = ""
        
        for event in response_stream:
            if 'chunk' in event:
                chunk = event['chunk']
                if 'bytes' in chunk:
                    response_text += chunk['bytes'].decode('utf-8')
        
        return response_text
    
    except Exception as e:
        logger.error(f"Error invoking Bedrock Agent: {str(e)}")
        raise

def process_agent_response(response, batch_id):
    """
    Process and log the agent's response
    """
    # Log the response for auditing and debugging
    logger.info(f"Agent response for batch {batch_id}: {response[:500]}...")
    
    # Here you could implement additional processing of the agent's response
    # such as extracting specific information, storing results in a database, etc.
    
    return response
