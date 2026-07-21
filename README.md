# IPDS Docs: Intelligent Protection & Detection System

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com/)
[![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white)](https://www.mongodb.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

IPDS Docs is a high-security, intelligent document management and storage system. It combines state-of-the-art encryption with a **Proactive Multi-Model AI** engine to provide deep analysis, secure summarization, and real-time threat detection for your sensitive documents.

---

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

---

## ✨ Key Features

- **Intelligent Summarization**: Adaptive length summaries based on document complexity.
- **Security Risk Detection**: Automatically identifies PII, leaked credentials, malware code, crypto keys, and more.
- **Cross-Platform**: Seamless experience on Android, iOS, Web, Windows, macOS, and Linux.
- **End-to-End Security**: Files are encrypted at rest and scanned via the IPDS Middleware on every request.
- **Live Monitoring**: Real-time WebSocket-based security event broadcasting and activity logging.

---

## 🛠️ Technology Stack

- **Frontend**: Flutter (Provider + GetX)
- **Backend**: FastAPI (Python)
- **Database**: MongoDB
- **AI Integration**: Groq, Google GenAI, OpenRouter, Mistral AI, HuggingFace

---

## 📦 Installation & Setup

### Prerequisites
- Flutter SDK (latest version)
- Python 3.10+
- MongoDB instance (local or Atlas)

### Backend Setup

1. Navigate to the `backend` directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Configure environment variables:
   Copy `.env.example` to `.env` and fill in your API keys (Keys are strictly loaded locally and excluded from version control):
   ```bash
   cp .env.example .env
   ```
   **Example `.env`**:
   ```env
   MONGO_URI=mongodb://localhost:27017
   GROQ_API_KEY=your_key
   GEMINI_API_KEY=your_key
   OPENROUTER_API_KEY=your_key
   ```
4. Start the server:
   ```bash
   uvicorn main:app --reload
   ```

### Frontend Setup

1. Navigate to the project root directory:
   ```bash
   cd ..
   ```
2. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---

## 🔒 Security Best Practices

- This project is configured to **automatically ignore** `.env` and sensitive API configurations.
- Ensure you never commit your private API keys or database credentials to version control.
- Modify the `SECRET_KEY` and `ENCRYPTION_KEY` in the `.env` file before deploying to a production environment.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](../../issues). 

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.
