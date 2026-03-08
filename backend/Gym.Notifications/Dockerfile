FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["Gym.Notifications/Gym.Notifications.csproj", "Gym.Notifications/"]
RUN dotnet restore "Gym.Notifications/Gym.Notifications.csproj"

COPY . .
WORKDIR /src/Gym.Notifications
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Gym.Notifications.dll"]
