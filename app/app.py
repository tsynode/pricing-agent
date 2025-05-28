"""
Streamlit UI for the Pricing Agent
"""
import streamlit as st
import uuid
import os
from datetime import datetime

# Direct import for Docker container environment
from agent import create_agent, save_agent_session, get_chat_list

# Set page configuration
st.set_page_config(
    page_title="Pricing Compliance Agent",
    page_icon="💰",
    layout="wide"
)

# Add the powered by message in the top left corner
# Get the model ID from environment variables
model_id = os.environ.get('MODEL_ID', 'anthropic.claude-3-haiku-20240307-v1:0')
# Format the model name for display (remove the vendor prefix and version suffix)
model_display = "claude-3-haiku-20240307"  # Hardcode for now to ensure correct display

st.markdown(
    f"Powered by AWS <span style='color: #FF9900;'>Strands Agents SDK</span> and Amazon Bedrock model: <span style='color: #FF9900;'>{model_display}</span>", 
    unsafe_allow_html=True
)

# Initialize session state
if "session_id" not in st.session_state:
    st.session_state.session_id = str(uuid.uuid4())
    st.session_state.messages = []
    st.session_state.agent = None
    st.session_state.chats = []
    st.session_state.show_chat_list = True

# Create or get the agent
if st.session_state.agent is None:
    with st.spinner("Initializing pricing agent..."):
        st.session_state.agent = create_agent(st.session_state.session_id)
        
# Fetch the list of previous chats
if st.session_state.show_chat_list:
    st.session_state.chats = get_chat_list()

# Sidebar for configuration and tools
with st.sidebar:
    st.title("Pricing Agent")
    st.markdown("---")
    
    # Chat management
    st.subheader("Chats")
    
    # New chat button
    if st.button("New Chat", key="new_chat"):
        st.session_state.session_id = str(uuid.uuid4())
        st.session_state.messages = []
        st.session_state.agent = create_agent()
        st.session_state.show_chat_list = True  # Refresh the chat list
        st.rerun()
    
    # Display previous chats
    if st.session_state.chats:
        st.write("Previous conversations:")
        for chat in st.session_state.chats[:10]:  # Limit to 10 most recent chats
            chat_id = chat.get('session_id')
            chat_title = chat.get('title')
            last_updated = chat.get('last_updated', '')
            
            # Format the date for display
            try:
                dt = datetime.fromisoformat(last_updated)
                date_str = dt.strftime("%b %d, %Y")
            except (ValueError, TypeError):
                date_str = "Unknown date"
            
            # Create a button for each chat
            if st.button(f"{chat_title}\n{date_str}", key=f"chat_{chat_id}"):
                if chat_id != st.session_state.session_id:  # Only switch if it's a different chat
                    st.session_state.session_id = chat_id
                    st.session_state.messages = []
                    st.session_state.agent = create_agent(chat_id)
                    st.rerun()
    else:
        st.write("No previous chats found")
        
    # Refresh chat list button
    if st.button("Refresh Chat List"):
        st.session_state.show_chat_list = True
        st.rerun()
    
    st.markdown("---")
    
    # Quick actions
    st.subheader("Quick Actions")
    
    # Check price compliance
    with st.expander("Check Price Compliance"):
        product_id = st.text_input("Product ID", key="check_product_id")
        price = st.number_input("Price", min_value=0.01, step=0.01, key="check_price")
        if st.button("Check Compliance"):
            if product_id and price > 0:
                prompt = f"Check if product {product_id} with price ${price:.2f} complies with pricing policies."
                st.session_state.messages.append({"role": "user", "content": prompt})
                st.rerun()
    
    # Scan inventory
    with st.expander("Scan Inventory"):
        category = st.text_input("Category (optional)", key="scan_category")
        compliance_only = st.checkbox("Show non-compliant items only", key="compliance_only")
        if st.button("Scan Inventory"):
            prompt = f"Scan the inventory"
            if category:
                prompt += f" for category '{category}'"
            if compliance_only:
                prompt += " and show only non-compliant items"
            prompt += "."
            st.session_state.messages.append({"role": "user", "content": prompt})
            st.rerun()
    
    # Get pricing policy
    with st.expander("Get Pricing Policy"):
        policy_category = st.text_input("Category (optional)", key="policy_category")
        if st.button("Get Policy"):
            prompt = "Explain the pricing policies"
            if policy_category:
                prompt += f" for {policy_category} products"
            prompt += "."
            st.session_state.messages.append({"role": "user", "content": prompt})
            st.rerun()
    
    st.markdown("---")

# Main chat interface
st.title("Pricing Compliance Agent")

# Display chat messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.write(message["content"])

# Check if there's an unprocessed message from sidebar actions
if st.session_state.messages and st.session_state.messages[-1]["role"] == "user" and "processed" not in st.session_state.messages[-1]:
    # Get the last user message
    last_message = st.session_state.messages[-1]["content"]
    
    # Generate assistant response
    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            # Get response from agent
            response = st.session_state.agent(last_message)
            
            # Display response - access the message attribute
            st.write(response.message)
            
            # Add assistant response to chat history
            st.session_state.messages.append({"role": "assistant", "content": response.message})
            
            # Mark the user message as processed
            st.session_state.messages[-2]["processed"] = True

# Chat input
if prompt := st.chat_input("Ask about pricing policies or compliance..."):
    # Add user message to chat history
    st.session_state.messages.append({"role": "user", "content": prompt})
    
    # Display user message
    with st.chat_message("user"):
        st.write(prompt)
    
    # Generate assistant response
    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            # Get response from agent
            response = st.session_state.agent(prompt)
            
            # Display response - access the message attribute
            st.write(response.message)
            
            # Add assistant response to chat history
            st.session_state.messages.append({"role": "assistant", "content": response.message})
            
            # Save session to DynamoDB
            save_agent_session(st.session_state.agent, st.session_state.session_id)
            
            # Mark that we should refresh the chat list on next load
            st.session_state.show_chat_list = True
