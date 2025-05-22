import streamlit as st
import boto3
import json
import time
import uuid
from datetime import datetime
import os

# Configure page settings
st.set_page_config(
    page_title="AI Pricing Compliance System",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Environment variables
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
BEDROCK_AGENT_ID = os.environ.get('BEDROCK_AGENT_ID')
BEDROCK_AGENT_ALIAS_ID = os.environ.get('BEDROCK_AGENT_ALIAS_ID')

# Initialize AWS clients
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime', region_name=AWS_REGION)
lambda_client = boto3.client('lambda', region_name=AWS_REGION)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        color: #1E88E5;
        margin-bottom: 1rem;
    }
    .sub-header {
        font-size: 1.5rem;
        color: #424242;
        margin-bottom: 1rem;
    }
    .status-box {
        padding: 1rem;
        border-radius: 0.5rem;
        margin-bottom: 1rem;
    }
    .status-box-success {
        background-color: #E8F5E9;
        border-left: 5px solid #4CAF50;
    }
    .status-box-warning {
        background-color: #FFF8E1;
        border-left: 5px solid #FFC107;
    }
    .status-box-error {
        background-color: #FFEBEE;
        border-left: 5px solid #F44336;
    }
    .response-area {
        background-color: #F5F5F5;
        padding: 1rem;
        border-radius: 0.5rem;
        margin-top: 1rem;
    }
    .footer {
        margin-top: 3rem;
        text-align: center;
        color: #9E9E9E;
    }
</style>
""", unsafe_allow_html=True)

# Health check endpoint for ALB
def health_check():
    return {"status": "healthy"}

# Create a route for the health check
if 'healthz' in st.experimental_get_query_params():
    st.write(health_check())
    st.stop()

# Session state initialization
if 'chat_history' not in st.session_state:
    st.session_state.chat_history = []

if 'scan_results' not in st.session_state:
    st.session_state.scan_results = None

# Header
st.markdown('<div class="main-header">AI Pricing Compliance System</div>', unsafe_allow_html=True)
st.markdown('<div class="sub-header">Intelligent pricing decisions powered by Amazon Bedrock</div>', unsafe_allow_html=True)

# Sidebar
with st.sidebar:
    st.markdown("## Actions")
    
    # Scan inventory button
    if st.button("🔍 Scan Entire Inventory", use_container_width=True):
        with st.spinner("Scanning inventory..."):
            try:
                # Find the inventory scanner Lambda function name
                lambda_functions = lambda_client.list_functions()
                inventory_scanner_function = None
                
                for function in lambda_functions['Functions']:
                    if 'inventory-scanner' in function['FunctionName']:
                        inventory_scanner_function = function['FunctionName']
                        break
                
                if inventory_scanner_function:
                    # Invoke the inventory scanner Lambda
                    response = lambda_client.invoke(
                        FunctionName=inventory_scanner_function,
                        InvocationType='RequestResponse',
                        Payload=json.dumps({
                            'source': 'streamlit',
                            'timestamp': datetime.utcnow().isoformat()
                        })
                    )
                    
                    # Parse the response
                    response_payload = json.loads(response['Payload'].read().decode('utf-8'))
                    st.session_state.scan_results = response_payload
                    
                    st.success(f"Scan complete! {response_payload.get('total_items', 0)} items processed in {response_payload.get('batches_created', 0)} batches.")
                else:
                    st.error("Inventory scanner Lambda function not found.")
            except Exception as e:
                st.error(f"Error scanning inventory: {str(e)}")
    
    st.markdown("---")
    
    st.markdown("## Filters")
    category = st.selectbox(
        "Product Category",
        ["All Categories", "Electronics", "Apparel", "Home Goods", "Sporting Goods", "Toys"]
    )
    
    compliance_status = st.radio(
        "Compliance Status",
        ["All", "Compliant", "Non-Compliant"]
    )
    
    st.markdown("---")
    
    st.markdown("## Recent Activity")
    st.markdown("Last scan: 2025-05-21 20:30:00")
    st.markdown("Items updated: 127")
    st.markdown("Compliance rate: 94.3%")

# Main content
tabs = st.tabs(["Query Assistant", "Compliance Dashboard", "Pricing Policies"])

# Query Assistant Tab
with tabs[0]:
    st.markdown("### Ask about pricing compliance")
    st.markdown("Use natural language to query the AI agent about pricing compliance, policies, or specific products.")
    
    # Query input
    query = st.text_input(
        "Enter your query:",
        placeholder="Do we have any non-compliant items in electronics?",
        key="query_input"
    )
    
    # Submit button
    if st.button("Submit Query", key="submit_query"):
        if query:
            with st.spinner("Processing your query..."):
                try:
                    # Add user query to chat history
                    st.session_state.chat_history.append({"role": "user", "content": query})
                    
                    # Create a session ID
                    session_id = f"pricing-compliance-{str(uuid.uuid4())}"
                    
                    # Invoke the Bedrock agent
                    response = bedrock_agent_runtime.invoke_agent(
                        agentId=BEDROCK_AGENT_ID,
                        agentAliasId=BEDROCK_AGENT_ALIAS_ID,
                        sessionId=session_id,
                        inputText=query
                    )
                    
                    # Extract the agent's response
                    response_stream = response.get('completion')
                    response_text = ""
                    
                    for event in response_stream:
                        if 'chunk' in event:
                            chunk = event['chunk']
                            if 'bytes' in chunk:
                                response_text += chunk['bytes'].decode('utf-8')
                    
                    # Add agent response to chat history
                    st.session_state.chat_history.append({"role": "assistant", "content": response_text})
                    
                except Exception as e:
                    error_message = f"Error processing query: {str(e)}"
                    st.error(error_message)
                    st.session_state.chat_history.append({"role": "assistant", "content": f"Error: {error_message}"})
        else:
            st.warning("Please enter a query.")
    
    # Display chat history
    st.markdown("### Conversation History")
    for message in st.session_state.chat_history:
        if message["role"] == "user":
            st.markdown(f"**You:** {message['content']}")
        else:
            st.markdown(f"**AI Assistant:** {message['content']}")
        st.markdown("---")

# Compliance Dashboard Tab
with tabs[1]:
    st.markdown("### Pricing Compliance Dashboard")
    
    # Display scan results if available
    if st.session_state.scan_results:
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Total Items Scanned", st.session_state.scan_results.get('total_items', 0))
        
        with col2:
            st.metric("Batches Created", st.session_state.scan_results.get('batches_created', 0))
        
        with col3:
            # This would be calculated based on actual compliance data
            st.metric("Compliance Rate", "94.3%")
        
        st.markdown("### Recent Price Updates")
        # This would be populated with actual data from DynamoDB
        sample_data = [
            {"item_id": "ELEC-12345", "old_price": 199.99, "new_price": 219.99, "reason": "Margin below minimum threshold", "timestamp": "2025-05-21T20:15:23Z"},
            {"item_id": "APRL-54321", "old_price": 49.99, "new_price": 44.99, "reason": "Seasonal discount policy applied", "timestamp": "2025-05-21T20:12:45Z"},
            {"item_id": "HOME-98765", "old_price": 129.99, "new_price": 119.99, "reason": "Competitive pricing adjustment", "timestamp": "2025-05-21T20:10:12Z"}
        ]
        
        st.dataframe(
            sample_data,
            column_config={
                "item_id": "Item ID",
                "old_price": st.column_config.NumberColumn("Old Price", format="$%.2f"),
                "new_price": st.column_config.NumberColumn("New Price", format="$%.2f"),
                "reason": "Reason for Change",
                "timestamp": "Timestamp"
            },
            hide_index=True
        )
    else:
        st.info("No scan results available. Click 'Scan Entire Inventory' to start a compliance check.")

# Pricing Policies Tab
with tabs[2]:
    st.markdown("### Current Pricing Policies")
    
    # Sample policies for demonstration
    policies = [
        {
            "name": "Minimum Margin Requirements",
            "description": "All products must maintain a minimum margin of 30% except during clearance events.",
            "category": "General",
            "last_updated": "2025-04-15"
        },
        {
            "name": "Electronics Pricing Strategy",
            "description": "Electronics must be priced within 5% of major competitors and maintain minimum 25% margin.",
            "category": "Electronics",
            "last_updated": "2025-05-01"
        },
        {
            "name": "Seasonal Apparel Discounts",
            "description": "End-of-season apparel receives automatic 15-30% discount based on inventory levels.",
            "category": "Apparel",
            "last_updated": "2025-05-10"
        }
    ]
    
    for policy in policies:
        with st.expander(f"{policy['name']} ({policy['category']})"):
            st.markdown(f"**Description:** {policy['description']}")
            st.markdown(f"**Last Updated:** {policy['last_updated']}")

# Footer
st.markdown('<div class="footer">AI Pricing Compliance System © 2025</div>', unsafe_allow_html=True)
