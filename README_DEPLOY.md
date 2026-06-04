# 🚀 Cinegram - Multi-Platform 1-Click Deployment Guide

This guide walks you through hosting your **Cinegram Express.js Backend Gateway** on various cloud hosting providers and VPS instances. The backend is pre-configured to run efficiently in low-memory environments (like 512MB RAM free tiers) and uses Supabase for database session persistence.

---

## 📋 Prerequisites & Credentials
Before deploying, make sure you have:
1. **GitHub Repository** containing this project.
2. **Telegram API Developer Credentials** ([my.telegram.org](https://my.telegram.org)).
3. **TMDB API Key** ([themoviedb.org](https://www.themoviedb.org/)).
4. **Supabase Project** ([supabase.com](https://supabase.com)) with the [`supabase_schema.sql`](file:///f:/Games/Project%20Don't%20Delete%20This%20Folder/supabase_schema.sql) applied in the SQL Editor.
5. **Telegram Session String**: Run `node login.js` locally inside the `backend/` directory to generate your persistent session string (`TELEGRAM_SESSION_STRING`).

---

## ⚡ 1-Click Cloud Deployment Options

### 1. Railway (Recommended)
Railway is stateless-safe, supports github-triggered deploys, and has a native variables panel.
1. Log in to [Railway.app](https://railway.app).
2. Click **New Project > Deploy from GitHub** and connect your repo.
3. Railway will automatically detect the configuration from [`railway.json`](file:///f:/Games/Project%20Don%27t%20Delete%20This%20Folder/railway.json) at the root.
4. Fill in the environment variables:
   - `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, `TELEGRAM_SESSION_STRING`
   - `TMDB_API_KEY`, `SUPABASE_URL`, `SUPABASE_KEY`
5. Click **Deploy**.

---

### 2. Koyeb (Free Nano Instance)
Koyeb Nano instance has no sleep timers on inactivity, making it perfect for always-on streaming.
1. Log in to [Koyeb.com](https://www.koyeb.com).
2. Click **Create Service > GitHub** and select your repository.
3. Koyeb will configure the service using the [`koyeb.yaml`](file:///f:/Games/Project%20Don%27t%20Delete%20This%20Folder/koyeb.yaml) file at the root.
4. Set up the environment variables under **App Settings**.
5. Click **Deploy**.

---

### 3. Hugging Face Spaces (Docker Space)
Hugging Face Spaces provides free hosting with no cold-starts, building directly from your Docker configuration.
1. Log in to [Hugging Face](https://huggingface.co) and create a **New Space**.
2. Select **Docker** as the SDK, and select **Blank** template.
3. Copy your project files to the Space repository.
4. Add the following YAML metadata block at the top of your Hugging Face Space `README.md` to configure the build:
   ```yaml
   ---
   title: Cinegram Gateway
   emoji: 🎥
   colorFrom: purple
   colorTo: indigo
   sdk: docker
   app_port: 3000
   ---
   ```
5. Add your secure variables in **Space Settings > Variables and secrets** as Space Secrets.

---

### 4. Render (Blueprint YAML)
Render deploys using Render Blueprints using the [`render.yaml`](file:///f:/Games/Project%20Don%27t%20Delete%20This%20Folder/render.yaml) file.
1. Go to your [Render Dashboard](https://dashboard.render.com).
2. Click **New + > Blueprint**.
3. Select your **Cinegram** repository, name the blueprint group, and enter the environment variables when prompted.
4. Click **Apply**.

---

## 🏠 VPS Self-Host Deployment (Recommended for Production)
For actual public streaming, deploying on a VPS (DigitalOcean, Linode, Contabo) is the most reliable option.

### Setup Instructions
1. Install Docker and Docker Compose on your VPS.
2. Clone your Cinegram repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/CineGram.git && cd CineGram
   ```
3. Create a `.env` file in the root directory:
   ```env
   TELEGRAM_API_ID="your_telegram_api_id"
   TELEGRAM_API_HASH="your_telegram_api_hash"
   TELEGRAM_SESSION_STRING="your_persistent_session_string"
   TMDB_API_KEY="your_tmdb_api_key"
   SUPABASE_URL="your_supabase_url"
   SUPABASE_KEY="your_supabase_anon_or_service_role_key"
   TELEGRAM_BOT_TOKEN="optional_bot_token"
   ```
4. Start the service with one command:
   ```bash
   docker compose up -d --build
   ```

---

## 🔍 Health Check Verification
To verify your deployment is successful, check the `/health` endpoint on your deployed URL:
```json
{
  "status": "healthy",
  "telegram_connected": true,
  "supabase_configured": true,
  "tmdb_configured": true
}
```
