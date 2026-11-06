# ========================================== 
# Claude Code Local Ollama Integration Configuration 
# ========================================== 
# Dedicated function to launch Claude Code with local models 

# 1. Base URL Routing to Ollama's native Anthropic compatibility layer 
export ANTHROPIC_BASE_URL="http://localhost:11434" 

# 2. Required placeholder API Key to bypass the cloud authentication block 
export ANTHROPIC_API_KEY="ollama" 

# 3. Comprehensive Model Tier Remapping 
# Overrides all internal fallback tiers to target your local model directly 
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen3.8" 
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen3.8" 
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen3.8" 
export CLAUDE_CODE_DEFAULT_MODEL="qwen3.8" 

# 4. Feature Tuning and Guardrails 
# Suppresses non-essential background traffic and cloud model lookup lookups 
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 
# Bypasses strict cloud window constraints for unmapped local model tags 
export CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1 
# Manually declares token limits to manage auto-compaction cleanly 
export CLAUDE_CODE_MAX_CONTEXT_TOKENS=200000
# 5. Core Execution Command 
# Automatically triggers a fresh, uncorrupted session in stream-only layout 
claude --bare 
