using GrpcServer.Services;
using GrpcServer.Interceptors;
using GrpcServer.Config;
using OpenMatch;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<OpenMatchSettings>(
    builder.Configuration.GetSection("OpenMatch"));

builder.Services.AddGrpc(options =>
{
    options.Interceptors.Add<GrpcExceptionInterceptor>();
});

builder.Services.AddSingleton(sp =>
{
    var config = sp.GetRequiredService<IOptions<OpenMatchSettings>>().Value;
    var channel = Grpc.Net.Client.GrpcChannel.ForAddress($"{config.FrontendHost}:{config.FrontendPort}");
    return new FrontendService.FrontendServiceClient(channel);
});

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGrpcService<MatchService>();
app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client.");

app.Run();
