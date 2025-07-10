using System.Collections.Concurrent;
using Grpc.Core;
using GrpcServer.Config;
using MatchMaker;
using Microsoft.Extensions.Options;
using OpenMatch;

namespace GrpcServer.Services;

public class MatchService : MatchMaker.MatchService.MatchServiceBase
{
    private readonly ILogger<MatchService> _logger;
    private readonly FrontendService.FrontendServiceClient _frontend;
    private readonly OpenMatchSettings _omSettings;

    public MatchService(ILogger<MatchService> logger, FrontendService.FrontendServiceClient frontend, IOptions<OpenMatchSettings> omSettings)
    {
        _logger = logger;
        _frontend = frontend;
        _omSettings = omSettings.Value;
    }

    public override async Task<StartMatchResponse> StartMatch(StartMatchRequest request, ServerCallContext context)
    {
        _logger.LogInformation($"Received StartMatchRequest for player {request.UserId}");

        var ticket = new Ticket
        {
            SearchFields = new SearchFields
            {
                Tags = { request.Mode }
            },
        };

        var omReq = new CreateTicketRequest { Ticket = ticket };
        var omRes = await _frontend.CreateTicketAsync(omReq);

        return new StartMatchResponse { Result = 200, TicketId = omRes.Id };
    }

    public override async Task WatchTicket(WatchTicketRequest request, IServerStreamWriter<GameAssignment> responseStream, ServerCallContext context)
    {
        _logger.LogInformation($"Received WatchTicketRequest for ticket {request.TicketId}");

        var ticketId = request.TicketId;
        var start = DateTime.UtcNow;
        var timeout = TimeSpan.FromSeconds(10); // TODO Const로 빼기

        while (!context.CancellationToken.IsCancellationRequested)
        {
            try
            {
                var omRes = await _frontend.GetTicketAsync(new GetTicketRequest { TicketId = ticketId });

                _logger.LogInformation($"Received GetTicketAsync {omRes}");

                if (omRes.Assignment != null)
                {
                    await responseStream.WriteAsync(new GameAssignment
                    {
                        Result = 200,
                        Connection = omRes.Assignment.Connection
                    });
                    return;
                }
            }
            catch (RpcException ex) when (ex.StatusCode == StatusCode.NotFound)
            {
                _logger.LogError($"Received RpcException {ex}");
                
                await responseStream.WriteAsync(new GameAssignment
                {
                    Result = 100000, // TODO error code
                });
                return;
            }

            if (DateTime.UtcNow - start > timeout)
            {
                await responseStream.WriteAsync(new GameAssignment
                {
                    Result = 100001,
                    Connection = "",
                });
                return;
            }

            await Task.Delay(1000);
        }
    }

    public override async Task<CancelMatchResponse> CancelMatch(CancelMatchRequest request, ServerCallContext context)
    {
        _logger.LogInformation($"Received CancelMatchRequest for ticket {request.TicketId}");

        var omReq = new DeleteTicketRequest { TicketId = request.TicketId };
        await _frontend.DeleteTicketAsync(omReq);

        return new CancelMatchResponse { Result = 200 };
    }
}
