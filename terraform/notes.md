### Important Manual Steps for Databricks

To grant an admin role to a service principal in Databricks, you need to be either an account admin or a workspace admin. You can add the service principal to the admins group through the Settings > Identity and Access > Groups section. This grants it the same permissions as a standard admin user.
Steps to grant admin role to a service principal:
Login as a Workspace Admin: Log in to your Databricks workspace with an account that has admin privileges.
Navigate to Identity and Access: Click your username in the top bar, select "Settings," then "Identity and Access".
Manage Groups: Click "Manage" next to "Groups".
Select the Admins Group: Choose the "admins" system group.
Add Members: Click "Add members" and select the service principal you want to add.
Confirm: Confirm the addition of the service principal to the group.



ANOTHER ONE

When setting up the Service Principal, need to grant it privilege to create external locations
Find the `Application ID` from the Workspace Settings >> Identity and access >> Service principals UI
Run this statement in the SQL editor:
GRANT CREATE EXTERNAL LOCATION ON METASTORE TO `your_service_principal_application_id`;

GRANT CREATE EXTERNAL LOCATION ON METASTORE TO `1718b555-05ea-4664-afcf-8b08473286fc`;


**Confluent Model Provider Notes**

Let me search for information specifically about models available with `confluent` as the provider in the Confluent Flink documentation.

Ran tool
Let me search for more specific information about models available with `confluent` as the provider.

Ran tool
Let me search for more specific information about models available with `confluent` as the provider in Confluent Flink AI model inference.

Ran tool
Based on my search results, I can see that when using `confluent` as the provider in Confluent Flink AI model inference, the available models are primarily **Meta Llama models**. Here are the models available with `confluent` as the provider:

## Models Available with `confluent` Provider

### **Meta Llama Models:**

1. **meta-llama/Llama-3.1-8B-Instruct** (which you're currently using)
2. **meta-llama/Llama-3.2-3B-Instruct**
3. **meta-llama/Llama-3.2-1B-Instruct**
4. **meta-llama/Llama-3.1-70B-Instruct**
5. **meta-llama/Llama-3.1-405B-Instruct**

### **Key Details:**

- **Provider**: `confluent`
- **Model Family**: Meta Llama 3.1 and 3.2 series
- **Supported Languages**: English, German, French, Italian, Portuguese, Hindi, Spanish, and Thai
- **Context Length**: Up to 128k tokens (for 3.1 series), 8k-128k (for 3.2 series)
- **Use Cases**: Chat, instruction following, code generation, multilingual dialogue, tool use, reasoning, and math

### **Model Sizes Available:**
- **1B parameters**: Llama-3.2-1B-Instruct (lightweight, mobile-optimized)
- **3B parameters**: Llama-3.2-3B-Instruct (balanced performance/efficiency)
- **8B parameters**: Llama-3.1-8B-Instruct (your current model)
- **70B parameters**: Llama-3.1-70B-Instruct (high performance)
- **405B parameters**: Llama-3.1-405B-Instruct (maximum capability)

The `confluent` provider specifically hosts Meta's Llama model family, which are open-source large language models optimized for instruction following and conversational AI tasks. These models are particularly well-suited for enterprise applications due to their commercial licensing and strong performance across various benchmarks.


For summarizing many hotel reviews into a concise 2-3 sentence output, I'd recommend **meta-llama/Llama-3.1-8B-Instruct** (which you're already using) or **meta-llama/Llama-3.2-3B-Instruct** as the optimal choices. Here's why:

## **Best Options for Hotel Review Summarization:**

### **1. Llama-3.1-8B-Instruct (Your Current Model) - RECOMMENDED**
- **Excellent for summarization tasks** with strong performance on reading comprehension benchmarks
- **128k context length** - can process many reviews in a single request
- **Balanced performance/cost** ratio for production use
- **Strong instruction following** (IFEval score: 80.4) - will reliably follow your "2-3 sentence" constraint
- **Multilingual support** - handles reviews in 8 languages

### **2. Llama-3.2-3B-Instruct - GOOD ALTERNATIVE**
- **Specifically optimized for summarization tasks** (TLDR9+ benchmark: 19.0 ROUGE-L score)
- **More cost-effective** and faster inference
- **Good instruction following** (IFEval score: 77.4)
- **128k context length** for processing multiple reviews
- **Lower resource requirements** while maintaining quality

## **Why These Are Better Than Others:**

- **Llama-3.2-1B**: Too small for nuanced summarization of complex review content
- **Llama-3.1-70B/405B**: Overkill for this task - higher cost with minimal quality improvement for summarization

## **Recommendation:**
**Stick with Llama-3.1-8B-Instruct** since you're already using it. It has proven strong summarization capabilities and the 128k context window allows you to process many hotel reviews simultaneously. The model excels at extracting key themes and sentiment from multiple sources and condensing them into coherent, concise summaries.

If cost optimization is important, **Llama-3.2-3B-Instruct** would be an excellent alternative that's specifically tuned for summarization tasks while being more efficient.
