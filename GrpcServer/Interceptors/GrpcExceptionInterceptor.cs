using Grpc.Core;
using Grpc.Core.Interceptors;
using Microsoft.Extensions.Logging;

namespace GrpcServer.Interceptors;

public class GrpcExceptionInterceptor : Interceptor
{
    private readonly ILogger<GrpcExceptionInterceptor> _logger;

    public GrpcExceptionInterceptor(ILogger<GrpcExceptionInterceptor> logger)
    {
        _logger = logger;
    }

    public override async Task<TResponse> UnaryServerHandler<TRequest, TResponse>(TRequest request, ServerCallContext context, UnaryServerMethod<TRequest, TResponse> continuation)
    {
        try
        {
            return await continuation(request, context);
        }
        catch (RpcException ex)
        {
            _logger.LogError(ex, "[gRPC] RpcException: {Status} - {Message}", ex.StatusCode, ex.Status.Detail);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[gRPC] Unhandled exception");
            throw new RpcException(new Status(StatusCode.Internal, "Server Error"));
        }
    }
    
    public override async Task ServerStreamingServerHandler<TRequest, TResponse>(
        TRequest request,
        IServerStreamWriter<TResponse> responseStream,
        ServerCallContext context,
        ServerStreamingServerMethod<TRequest, TResponse> continuation)
    {
        try
        {
            await continuation(request, responseStream, context);
        }
        catch (RpcException ex)
        {
            _logger.LogError(ex, "[gRPC] RpcException: {Status} - {Message}", ex.StatusCode, ex.Status.Detail);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[gRPC] Unhandled exception");
            throw new RpcException(new Status(StatusCode.Internal, "Server Error"));
        }
    }
}
