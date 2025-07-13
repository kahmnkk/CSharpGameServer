using Agones;
using System;
using System.Threading.Tasks;

namespace GameServer.Core;

public class AgonesWrapper
{
    private AgonesSDK _sdk;
    private readonly CancellationTokenSource _cts = new();

    public event Action? OnAllocated;

    public AgonesWrapper()
    {
        _sdk = new AgonesSDK();
    }

    public async Task Run()
    {
        try
        {
            Console.WriteLine("[Agones] Ready");
            await _sdk.ReadyAsync();

            _ = Task.Run(async () => await RunHealthPing(_cts.Token));

            WatchGameServer();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Agones] Failed to start: {ex.Message}");
        }
    }

    private async Task RunHealthPing(CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                await _sdk.HealthAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Agones] Health ping failed: {ex.Message}");
            }

            await Task.Delay(TimeSpan.FromSeconds(2), token);
        }
    }

    private void WatchGameServer()
    {
        _sdk.WatchGameServer(gs =>
        {
            Console.WriteLine("[Agones] WatchGameServer");

            var state = gs.Status?.State;
            if (state != "Allocated")
                return;

            OnAllocated?.Invoke();
        });
    }

    public async Task Shutdown()
    {
        try
        {
            Console.WriteLine("[Agones] Shutdown");
            _cts.Cancel();
            await _sdk.ShutDownAsync();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Agones] Shutdown failed: {ex.Message}");
        }
    }
}
