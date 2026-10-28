# ---- Build stage ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj files and restore (layer cache)
COPY Directory.Build.props Directory.Packages.props GovConnect.slnx ./
COPY src/GovConnect.Api/*.csproj           src/GovConnect.Api/
COPY src/GovConnect.Application/*.csproj   src/GovConnect.Application/
COPY src/GovConnect.Database/*.csproj      src/GovConnect.Database/
COPY src/GovConnect.Domain/*.csproj        src/GovConnect.Domain/
COPY src/GovConnect.Infrastructure/*.csproj src/GovConnect.Infrastructure/
RUN dotnet restore src/GovConnect.Api/GovConnect.Api.csproj

# Copy everything and publish
COPY src/ src/
RUN dotnet publish src/GovConnect.Api/GovConnect.Api.csproj \
    -c Release -o /app/publish --no-restore

# ---- Runtime stage ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8002
EXPOSE 8002

ENTRYPOINT ["dotnet", "GovConnect.Api.dll"]
