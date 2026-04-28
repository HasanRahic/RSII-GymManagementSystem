Write-Host "Pokrecem SQL Server, RabbitMQ i notification worker kroz docker compose..." -ForegroundColor Cyan
docker compose up -d sqlserver rabbitmq gym.notifications

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker compose nije uspjesno pokrenut."
    exit $LASTEXITCODE
}

Write-Host "Pokrecem Gym.Api lokalno..." -ForegroundColor Cyan
dotnet run --project ".\backend\Gym.Api\Gym.Api.csproj"
