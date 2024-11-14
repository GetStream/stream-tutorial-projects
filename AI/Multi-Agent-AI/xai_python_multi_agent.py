
from phi.agent import Agent
from phi.model.openai import OpenAIChat
from phi.tools.duckduckgo import DuckDuckGo
from phi.tools.yfinance import YFinanceTools
from phi.model.xai import xAI
from phi.playground import Playground, serve_playground_app
from fastapi import FastAPI


# Create web search agent with improved instructions
web_search_agent = Agent(
    name="Web Search Agent",
    role="Search the web for accurate and up-to-date information",
    model=xAI(id="grok-beta"),
    tools=[DuckDuckGo()],
    instructions=[
        "Always include sources and citations",
        "Verify information from multiple sources when possible",
        "Present information in a clear, structured format",
    ],
    show_tool_calls=True,
    markdown=True,
    monitoring=True,  # Enable monitoring for better debugging
)

# Create finance agent with enhanced capabilities
finance_agent = Agent(
    name="Finance Agent",
    role="Analyze and present financial data",
    model=xAI(id="grok-beta"),
    tools=[
        YFinanceTools(
            stock_price=True,
            analyst_recommendations=True,
            company_info=True,
            company_news=True,  # Added news capability
        )
    ],
    instructions=[
        "Use tables to display numerical data",
        "Include key financial metrics and trends",
        "Provide context for financial recommendations",
    ],
    show_tool_calls=True,
    markdown=True,
    monitoring=True,
)

# Create multi-agent team with improved coordination
multi_ai_agent = Agent(
    name="Multi AI Team",
    team=[web_search_agent, finance_agent],
    model=xAI(id="grok-beta"),
    instructions=[
        "Always include sources and citations",
        "Use tables to display structured data",
        "Combine financial data with relevant market news",
        "Provide comprehensive analysis using both agents' capabilities",
    ],
    show_tool_calls=True,
    markdown=True,
    monitoring=True,
)

# Create playground with both agents
app = Playground(agents=[multi_ai_agent]).get_app()

if __name__ == "__main__":
    serve_playground_app("multi_ai_agent:app", reload=True, port=7777)
