using System;
using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace GameServer.Core;

class Server
{
    private TcpListener _listener;
    private AgonesWrapper _agones;
    private bool _isRunning = false;
    private readonly ConcurrentDictionary<string, Session> _clients = new();
    private DateTime _lastPacketTime;

    public Server(int port)
    {
        _listener = new TcpListener(IPAddress.Any, port);
        _agones = new AgonesWrapper();
        _agones.OnAllocated += OnAllocated;
    }

    public async Task Run()
    {
        Console.WriteLine($"[Server] Running...");

        _listener.Start();

        await _agones.Run();

        _isRunning = true;
        while (_isRunning)
        {
            TcpClient? client;
            try
            {
                client = await _listener.AcceptTcpClientAsync();

            }
            catch (SocketException ex) when (ex.SocketErrorCode == SocketError.OperationAborted)
            {
                Console.WriteLine("[Server] Listener stopped gracefully.");
                break;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Server] Accept failed: {ex.Message}");
                continue;
            }

            var session = new Session(client);
            _clients.TryAdd(session.Id, session);

            Console.WriteLine($"[Server] New client connected: {session.Id} {client.Client.RemoteEndPoint}");

            _ = HandleClient(session);
        }
    }

    private async Task HandleClient(Session session)
    {
        var buffer = new byte[1024];
        var client = session.Client;
        var stream = session.Stream;

        try
        {
            while (_isRunning && client.Connected)
            {
                int byteCount = await stream.ReadAsync(buffer);
                if (byteCount <= 0) break;

                _lastPacketTime = DateTime.UtcNow;

                var message = Encoding.UTF8.GetString(buffer, 0, byteCount);
                Console.WriteLine($"[Recv] {session.Id}: {message}");

                // 모든 클라이언트에게 브로드캐스트
                await Broadcast($"{session.Id}: {message}");
            }
        }
        catch (Exception e)
        {
            Console.WriteLine($"[Error] {e.Message}");
        }
        finally
        {
            Console.WriteLine($"[Server] Client disconnected: {session.Id} {client.Client.RemoteEndPoint}");
            _clients.TryRemove(session.Id, out _);
            client.Close();
        }
    }

    private async Task Broadcast(string message)
    {
        byte[] data = Encoding.UTF8.GetBytes(message);

        foreach (var client in _clients)
        {
            try
            {
                await client.Value.Stream.WriteAsync(data);
            }
            catch
            {
                // ignore broken clients
            }
        }
    }

    public void Stop()
    {
        Console.WriteLine($"[Server] Stoping...");

        _isRunning = false;
        _listener.Stop();
        foreach (var client in _clients)
        {
            client.Value.Client.Close();
        }

        Console.WriteLine($"[Server] Stopped");
    }

    private void OnAllocated()
    {
        Console.WriteLine("[Server] Allocated");

        _lastPacketTime = DateTime.UtcNow;

        // Check Zombie Server
        _ = Task.Run(async () =>
        {
            while (true)
            {
                var inactiveTime = DateTime.UtcNow - _lastPacketTime;
                if (inactiveTime > TimeSpan.FromSeconds(30))
                {
                    Console.WriteLine("[Server] Zombie server shutdown");

                    await _agones.Shutdown();
                    Stop();
                }

                await Task.Delay(TimeSpan.FromSeconds(5));
            }
        });
    }
}
