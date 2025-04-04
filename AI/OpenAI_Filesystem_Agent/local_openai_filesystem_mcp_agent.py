# https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem

import streamlit as st
import asyncio
import os
import shutil
import tempfile
import glob

from agents import Agent, Runner, OpenAIChatCompletionsModel, AsyncOpenAI
from openai.types.responses import ResponseTextDeltaEvent


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


# Function to read all files in the sample directory and return their contents
def read_sample_files():
    samples_dir = ensure_sample_files()
    file_contents = {}
    
    # Read all files in the directory
    for file_path in glob.glob(os.path.join(samples_dir, "*")):
        if os.path.isfile(file_path):
            with open(file_path, 'r') as file:
                file_contents[os.path.basename(file_path)] = file.read()
    
    return file_contents


# Function to build context from file contents
def build_context_from_files():
    file_contents = read_sample_files()
    context = "Here are the contents of the files in the system:\n\n"
    
    for filename, content in file_contents.items():
        context += f"--- File: {filename} ---\n{content}\n\n"
    
    return context


# Function to run a query with error handling
def run_agent_query(query):
    try:
        # Read all files and build context
        context = build_context_from_files()
        
        # Combine context and query
        full_prompt = f"{context}\n\nBased on the file contents above, {query}"
        
        async def run_query():
            try:
                # Initialize Ollama client and local model
                local_model = OpenAIChatCompletionsModel(
                    model="deepseek-r1:8b",
                    openai_client=AsyncOpenAI(base_url="http://localhost:11434/v1")
                )
                
                agent = Agent(
                    name="Assistant for Content in Files",
                    instructions="You are a helpful assistant that answers questions about the file contents provided in the context.",
                    model=local_model
                )
                
                result = await Runner.run(starting_agent=agent, input=full_prompt)
                return result.final_output, None  # No trace_id since we're not using MCP
            except Exception as e:
                st.error(f"Error in run_query: {str(e)}")
                return f"Failed to process query: {str(e)}", None
        
        return AsyncRunner.run_async(run_query)
    except Exception as e:
        st.error(f"Error processing query: {str(e)}")
        return f"Failed to process query: {str(e)}", None


# Function to run a streaming query with error handling
def run_agent_query_streamed(query):
    try:
        # Read all files and build context
        context = build_context_from_files()
        
        # Combine context and query
        full_prompt = f"{context}\n\nBased on the file contents above, {query}"
        
        async def run_streamed_query():
            try:
                # Create a placeholder for the streaming output
                response_placeholder = st.empty()
                full_response = ""
                
                # Initialize Ollama client and local model
                local_model = OpenAIChatCompletionsModel(
                    model="deepseek-r1:8b",
                    openai_client=AsyncOpenAI(base_url="http://localhost:11434/v1")
                )
                
                agent = Agent(
                    name="Assistant for Content in Files",
                    instructions="You are a helpful assistant that answers questions about the file contents provided in the context.",
                    model=local_model
                )
                
                # Stream the response
                result = Runner.run_streamed(agent, full_prompt)
                async for event in result.stream_events():
                    if event.type == "raw_response_event" and isinstance(event.data, ResponseTextDeltaEvent):
                        # Append new text to the full response
                        full_response += event.data.delta
                        # Update the placeholder with the accumulated text
                        response_placeholder.markdown(full_response)
                
                return full_response
            except Exception as e:
                st.error(f"Error in run_streamed_query: {str(e)}")
                return f"Failed to process query: {str(e)}"
        
        return AsyncRunner.run_async(run_streamed_query)
    except Exception as e:
        st.error(f"Error processing query: {str(e)}")
        return f"Failed to process query: {str(e)}"


def main():
    st.title("File Explorer Assistant with Ollama and deepseek-r1:8b")
    st.write("This app uses Ollama with deepseek-r1:8b model to read files and answer questions about them.")
    
    # Ensure sample files exist
    ensure_sample_files()
    
    # Display available files
    st.subheader("Available Files")
    files = read_sample_files()
    for filename in files.keys():
        st.write(f"- {filename}")
    
    # Input area for user queries
    query = st.text_area("Ask me about the files:", height=100)
    
    use_streaming = st.checkbox("Use streaming response", value=True)
    
    if st.button("Submit"):
        if query:
            with st.spinner("Processing your request..."):
                if use_streaming:
                    run_agent_query_streamed(query)
                else:
                    result, _ = run_agent_query(query)
                    st.write("### Response:")
                    st.write(result)
    
    # Sample queries
    st.sidebar.header("Sample Queries")
    if st.sidebar.button("List all files"):
        with st.spinner("Processing..."):
            if use_streaming:
                run_agent_query_streamed("List the names of all the files.")
            else:
                result, _ = run_agent_query("List the names of all the files.")
                st.write("### Files in the system:")
                st.write(result)
            
    if st.sidebar.button("WWDC Activities"):
        with st.spinner("Processing..."):
            if use_streaming:
                run_agent_query_streamed("What are my favorite WWDC activities?")
            else:
                result, _ = run_agent_query("What are my favorite WWDC activities?")
                st.write("### WWDC Activities:")
                st.write(result)
            
    if st.sidebar.button("WWDC25 Predictions"):
        with st.spinner("Processing..."):
            if use_streaming:
                run_agent_query_streamed("Look at my wwdc25 predictions. List the predictions that are most likely to be true.")
            else:
                result, _ = run_agent_query("Look at my wwdc25 predictions. List the predictions that are most likely to be true.")
                st.write("### WWDC25 Predictions Analysis:")
                st.write(result)


if __name__ == "__main__":
    # Check if the user has Ollama running with deepseek-r1:8b model
    import requests
    try:
        response = requests.get("http://localhost:11434/api/tags")
        if response.status_code == 200:
            models = response.json()["models"]
            deepseek_available = any("deepseek-r1:8b" in model["name"] for model in models)
            if not deepseek_available:
                st.error("deepseek-r1:8b model is not available in Ollama. Please run 'ollama pull deepseek-r1:8b' to download it.")
                st.stop()
        else:
            st.error("Unable to connect to Ollama API. Make sure Ollama is running.")
            st.stop()
    except requests.exceptions.ConnectionError:
        st.error("Unable to connect to Ollama. Make sure Ollama is running at http://localhost:11434")
        st.stop()
    
    main()
