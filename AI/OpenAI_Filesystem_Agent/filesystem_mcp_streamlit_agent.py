# https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem

import streamlit as st
import asyncio
import os
import shutil
import tempfile

from agents import Agent, Runner, gen_trace_id, trace
from agents.mcp import MCPServer, MCPServerStdio


# Create a sample file for demonstration if needed
def ensure_sample_files():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    samples_dir = os.path.join(current_dir, "sample_files")
    
    # Create the directory if it doesn't exist
    os.makedirs(samples_dir, exist_ok=True)
    
    # Create a sample WWDC predictions file
    predictions_file = os.path.join(samples_dir, "wwdc25_predictions.md")
    if not os.path.exists(predictions_file):
        with open(predictions_file, "w") as f:
            f.write("# WWDC25 Predictions\n\n")
            f.write("1. Apple Intelligence features for iPad\n")
            f.write("2. New Apple Watch with health sensors\n")
            f.write("3. Vision Pro 2 announcement\n")
            f.write("4. iOS 18 with advanced customization\n")
            f.write("5. macOS 15 with AI features\n")
    
    # Create a sample WWDC activities file
    activities_file = os.path.join(samples_dir, "wwdc_activities.txt")
    if not os.path.exists(activities_file):
        with open(activities_file, "w") as f:
            f.write("My favorite WWDC activities:\n\n")
            f.write("1. Attending sessions\n")
            f.write("2. Labs with Apple engineers\n")
            f.write("3. Networking events\n")
            f.write("4. Exploring new APIs\n")
            f.write("5. Hands-on demos\n")
    
    return samples_dir


# Using a separate event loop to run async code in Streamlit
class AsyncRunner:
    @staticmethod
    def run_async(func, *args, **kwargs):
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            return loop.run_until_complete(func(*args, **kwargs))
        finally:
            loop.close()


# Function to run a query with error handling
def run_agent_query(query):
    try:
        # Create a fresh server and agent for each query
        samples_dir = ensure_sample_files()
        
        async def run_query():
            server = None
            try:
                server = MCPServerStdio(
                    name="Filesystem Server, via npx",
                    params={
                        "command": "npx",
                        "args": ["-y", "@modelcontextprotocol/server-filesystem", samples_dir],
                    },
                )
                
                # Enter the server context
                mcp_server = await server.__aenter__()
                
                agent = Agent(
                    name="Assistant for Content in Files",
                    instructions="Use the tools to read the filesystem and answer questions based on those files.",
                    mcp_servers=[mcp_server],
                )
                
                trace_id = gen_trace_id()
                with trace(workflow_name="MCP Filesystem Query", trace_id=trace_id):
                    result = await Runner.run(starting_agent=agent, input=query)
                    return result.final_output, trace_id
            finally:
                # Make sure to properly exit the server context
                if server:
                    await server.__aexit__(None, None, None)
        
        return AsyncRunner.run_async(run_query)
    except Exception as e:
        st.error(f"Error processing query: {str(e)}")
        return f"Failed to process query: {str(e)}", None


def main():
    st.title("File Explorer Assistant")
    st.write("This app uses an AI agent to read files and answer questions about them.")
    
    # Ensure sample files exist
    ensure_sample_files()
    
    # Input area for user queries
    query = st.text_area("Ask me about the files:", height=100)
    
    if st.button("Submit"):
        if query:
            with st.spinner("Processing your request..."):
                result, trace_id = run_agent_query(query)
                
                if trace_id:
                    st.write("### Response:")
                    st.write(result)
                    
                    trace_url = f"https://platform.openai.com/traces/trace?trace_id={trace_id}"
                    st.write(f"[View trace]({trace_url})")
    
    # Sample queries
    st.sidebar.header("Sample Queries")
    if st.sidebar.button("List all files"):
        with st.spinner("Processing..."):
            result, trace_id = run_agent_query("Read the files and list them.")
            if trace_id:
                st.write("### Files in the system:")
                st.write(result)
            
    if st.sidebar.button("WWDC Activities"):
        with st.spinner("Processing..."):
            result, trace_id = run_agent_query("What are my favorite WWDC activities?")
            if trace_id:
                st.write("### WWDC Activities:")
                st.write(result)
            
    if st.sidebar.button("WWDC25 Predictions"):
        with st.spinner("Processing..."):
            result, trace_id = run_agent_query("Look at my wwdc25 predictions. List the predictions that are most likely to be true.")
            if trace_id:
                st.write("### WWDC25 Predictions Analysis:")
                st.write(result)


if __name__ == "__main__":
    # Let's make sure the user has npx installed
    if not shutil.which("npx"):
        st.error("npx is not installed. Please install it with `npm install -g npx`.")
    else:
        main()
