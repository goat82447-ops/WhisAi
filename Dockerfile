FROM node:22-alpine AS web-build
WORKDIR /src/web

COPY src/whis-ai-web/package.json src/whis-ai-web/package-lock.json ./
RUN npm ci

COPY src/whis-ai-web/ ./
RUN npm run build

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS api-build
WORKDIR /src

COPY src/WhisAi.Api/WhisAi.Api.csproj src/WhisAi.Api/
RUN dotnet restore src/WhisAi.Api/WhisAi.Api.csproj

COPY src/WhisAi.Api/ src/WhisAi.Api/
RUN dotnet publish src/WhisAi.Api/WhisAi.Api.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

COPY --from=api-build /app/publish ./
COPY --from=web-build /src/web/dist ./wwwroot

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 10000
USER $APP_UID

CMD ["sh", "-c", "exec dotnet KrishAi.Api.dll --urls http://0.0.0.0:${PORT:-10000}"]