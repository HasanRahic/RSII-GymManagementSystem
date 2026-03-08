FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["Gym.Api/Gym.Api.csproj",               "Gym.Api/"]
COPY ["Gym.Core/Gym.Core.csproj",              "Gym.Core/"]
COPY ["Gym.Infrastructure/Gym.Infrastructure.csproj", "Gym.Infrastructure/"]
COPY ["Gym.Services/Gym.Services.csproj",      "Gym.Services/"]
RUN dotnet restore "Gym.Api/Gym.Api.csproj"

COPY . .
WORKDIR /src/Gym.Api
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Gym.Api.dll"]
