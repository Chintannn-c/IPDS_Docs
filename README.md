# IPDS Docs: Intelligent Protection & Detection System

IPDS Docs is a high-security, intelligent document management and storage system. It combines state-of-the-art encryption with a **Proactive Multi-Model AI** engine to provide deep analysis, secure summarization, and real-time threat detection for your sensitive documents.

## 🚀 Proactive Multi-Model AI
The heart of IPDS Docs is its advanced AI orchestration layer, which utilizes a tiered failover system across multiple world-class providers. This ensures 100% uptime and the highest possible intelligence for every document.

### 🦾 Elite AI Stack
| Provider | Primary Model | Purpose |
| :--- | :--- | :--- |
| **Groq** | `llama-3.3-70b-versatile` | Instant-speed scanning and summarization. |
| **Google** | `gemini-3.1-pro-preview` | Deep reasoning and large-context analysis. |
| **OpenRouter** | `openai/gpt-5.5-pro` | Ultimate intelligence fallback for complex tasks. |
| **Anthropic** | `claude-opus-4.7` | High-tier reasoning fallback. |
| **Mistral** | `mistral-large-latest` | Stable, high-quality European AI. |

### 🛡️ Failover Logic
If a primary model (like Groq) is rate-limited or down, the system **proactively** escalates to the next tier (Gemini Pro, then GPT-5.5 Pro) without any user intervention.

## ✨ Features
- **Intelligent Summarization**: Adaptive length summaries based on document complexity.
- **Security Risk Detection**: Automatically identifies PII, leaked credentials, malware code, and more.
- **Cross-Platform**: Seamless experience on Android, iOS, Web, Windows, macOS, and Linux.
- **End-to-End Security**: Files are encrypted at rest and scanned via the IPDS Middleware on every request.
- **Live Monitoring**: Real-time WebSocket-based security event broadcasting and activity logging.

## 🛠️ Technology Stack
- **Frontend**: Flutter (Provider + GetX)
- **Backend**: FastAPI (Python)
- **Database**: MongoDB
- **AI SDKs**: Groq, Google Generative AI, Mistral AI, OpenRouter, Hugging Face Hub

## 📦 Installation & Setup

### Backend
1. Navigate to the `backend` directory.
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Configure your `.env` file with your API keys:
   ```env
   MONGO_URI=mongodb://localhost:27017
   GROQ_API_KEY=your_key
   GEMINI_API_KEY=your_key
   OPENROUTER_API_KEY=your_key
   MISTRAL_API_KEY=your_key
   ```
4. Start the server:
   ```bash
   python main.py
   ```

### Frontend
1. Navigate to the root directory.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## 📜 License
Internal Project - Copyright (c) 2026 Chintannn-c / IPDS_Docs
