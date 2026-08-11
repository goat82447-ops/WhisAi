# KrishAI

KrishAI is a .NET 10 and React assistant with general chat, browser voice input and read-aloud, document-grounded Q&A, and optional image generation. Chat defaults to OpenRouter's free-model router and also supports OpenAI-compatible providers such as TokenRouter.

## Assistant context features

- **Live questions** keeps browser speech recognition active after you turn it on and automatically submits each final spoken question. Use the visible control to stop listening.
- **Share screen** opens the browser's screen picker. While active, KrishAI sends a size-limited snapshot only with the next question; the selected chat model must support image input.
- **My story** stores up to 4,000 characters of editable background context in local browser storage and includes it with chat questions. Clear the field to forget it.
- **Privacy protection** excludes the native desktop window from supported Windows capture APIs while showing a persistent on/off indicator. It is not a covert monitoring or policy-evasion mode.

## Requirements

- .NET 10 SDK
- Node.js 20 or newer
- An OpenRouter API key or another OpenAI-compatible provider key
- Optional: an OpenAI API key for image generation

## Configure

### OpenRouter free models

Create your own key at https://openrouter.ai/settings/keys. The `openrouter/free` router has no inference charge but requires a key and has rate limits. Keep the key out of source control with .NET user secrets:

```powershell
Set-Location src/WhisAi.Api
dotnet user-secrets init
dotnet user-secrets set "AI:ApiKey" "YOUR_OPENROUTER_API_KEY"
```

The default endpoint is `https://openrouter.ai/api/v1/` and the default chat model is `openrouter/free`. Free-model availability and limits are controlled by OpenRouter.

### TokenRouter or another compatible provider

Configure any provider that supports the OpenAI `/chat/completions` contract:

```powershell
Set-Location src/WhisAi.Api
dotnet user-secrets set "AI:Provider" "TokenRouter"
dotnet user-secrets set "AI:ApiKey" "YOUR_PROVIDER_KEY"
dotnet user-secrets set "AI:BaseUrl" "YOUR_PROVIDER_API_V1_URL"
dotnet user-secrets set "AI:ChatModel" "YOUR_PROVIDER_MODEL"
```

Use the exact base URL and model identifier from that provider. KrishAI does not embed or distribute shared API keys.

### Optional image generation

OpenRouter chat does not use OpenAI's image-generation endpoint. To enable the Create tab separately:

```powershell
Set-Location src/WhisAi.Api
dotnet user-secrets set "OpenAI:ApiKey" "YOUR_OPENAI_API_KEY"
```

The default image model is `gpt-image-1`; override it with `OpenAI__ImageModel` when needed.

## Run

Start the API:

```powershell
dotnet run --project src/WhisAi.Api --launch-profile http
```

Start the client in another terminal:

```powershell
Set-Location src/whis-ai-web
npm install
npm run dev
```

Open http://localhost:5173. The API runs at http://localhost:5071.

Supported document types are PDF, TXT, Markdown, CSV, and JSON, up to 10 MB. Voice features use the browser Web Speech APIs and work best in Chromium-based browsers.

## Deploy to Render

Render deploys the React client and ASP.NET API together as one Docker web service. The deployed website supports chat, voice, documents, story context, explicit browser screen sharing, and optional image generation. The Windows WPF privacy desktop is local-only because Render containers run Linux.

1. Revoke any API key that has been pasted into chat or committed to source, then create a replacement OpenRouter key.
2. Push this repository to GitHub or GitLab.
3. In Render, choose **New > Blueprint** and select the repository. Render reads `render.yaml` and builds the root `Dockerfile`.
4. When prompted for `AI__ApiKey`, enter the replacement OpenRouter key. Never add it to `appsettings.json`, `.env`, `Dockerfile`, or `render.yaml`.
5. Deploy and wait for `/health` to report healthy. The React app and API use the same Render URL.

The home sidebar includes **Download desktop**. It downloads a self-contained Windows ZIP configured for the Render service it came from. Extract the entire ZIP and run `KrishAi.Desktop.exe`; the native privacy window then loads the deployed site automatically. The Windows package is not code-signed, so Windows SmartScreen may show a warning until you sign releases with a trusted certificate.

Regenerate the committed desktop download after desktop changes, before pushing to Render:

```powershell
.\tools\Publish-DesktopDownload.ps1
```

Image generation is optional. To enable it after deployment, add `OpenAI__ApiKey` in the Render service environment and redeploy. Use a real OpenAI key for that variable; an OpenRouter key does not support the OpenAI image endpoint.

For a local production-container test:

```powershell
docker build -t krishai .
docker run --rm -p 10000:10000 --env-file .env krishai
```

Open http://localhost:10000 and check http://localhost:10000/health. Copy `.env.example` to an untracked `.env` and fill it locally; never commit `.env`.

## Windows privacy desktop

After starting the API and client, launch the native desktop host:

```powershell
dotnet run --project src/WhisAi.Desktop
```

The desktop window enables Windows `WDA_EXCLUDEFROMCAPTURE` protection by default and shows whether Windows accepted it. Use the visible button in the title bar to turn protection on or off. On supported Windows 10 version 2004+ and Windows 11 capture paths, the window is omitted or blank in standard screen capture, including meeting applications that use those APIs.

Use the red `×` button or press `Ctrl+Shift+Q` from anywhere to immediately dispose the desktop WebView and close KrishAI.

This protection applies only to the native KrishAI desktop window. The browser tab at http://localhost:5173 is not protected. It is a privacy feature rather than a security or DRM guarantee, and behavior can vary by meeting-app version, capture mode, remote desktop software, or external camera. Do not use it to evade monitoring, proctoring, or organizational policy.

## Validate

```powershell
dotnet build WhisAi.slnx
Set-Location src/whis-ai-web
npm run build
npm run lint
```