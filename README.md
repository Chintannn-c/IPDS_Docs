# IPDS Docs: Intelligent Protection & Detection System

IPDS Docs is a high-security, intelligent document management and storage system. It combines state-of-the-art encryption with a **Proactive Multi-Model AI** engine to provide deep analysis, secure summarization, and real-time threat detection for your sensitive documents.

## 🚀 Proactive Multi-Model AI (Free-Tier Optimized)
The heart of IPDS Docs is its advanced AI orchestration layer, which utilizes a tiered failover system across multiple world-class providers. This version is optimized for **100% Free-Tier usage** without sacrificing intelligence or speed.

### 🦾 Categorical AI Stack
| Category | Model | Provider | Strengths |
| :--- | :--- | :--- | :--- |
| **Speed** | `llama-3.3-70b-versatile` | Groq | Instant-speed initial scanning. |
| **Context** | `gemini-3.1-flash-lite` | Google | Deep reasoning & massive document support. |
| **Reasoning** | `gpt-oss-120b:free` | OpenRouter | High-intelligence logic for complex reports. |
| **Stability** | `llama-3.3-70b-instruct:free` | OpenRouter | Reliable structured JSON extraction. |
| **Fastest** | `glm-4.5-air:free` | OpenRouter | High-performance fallback engine. |

### 🛡️ Smart Failover Logic
The system automatically orchestrates between these models to ensure zero-cost, high-reliability analysis:
1. **Primary**: Groq (Fastest) -> Google (Reliable)
2. **Fallback**: OpenRouter Reasoning -> Stability -> Fastest (Best-in-class free models)
This ensures 100% uptime and the highest possible intelligence for every document without requiring paid subscriptions.

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
- **AI SDKs**: Groq, Google GenAI, OpenRouter, Mistral AI

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
