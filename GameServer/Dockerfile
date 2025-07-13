FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /app

COPY *.csproj ./
RUN dotnet restore

COPY . ./
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# For Agones SDK gRPC
RUN apt-get update && apt-get install -y ca-certificates

COPY --from=build /app/out ./

ENTRYPOINT ["dotnet", "GameServer.dll"]
