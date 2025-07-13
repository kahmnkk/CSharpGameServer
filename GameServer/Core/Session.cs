using System.Net.Sockets;

namespace GameServer.Core;

class Session(TcpClient client)
{
    public string Id { get; } = Guid.NewGuid().ToString();
    public TcpClient Client { get; } = client;
    public NetworkStream Stream { get; } = client.GetStream();
    public DateTime ConnectedAt { get; } = DateTime.UtcNow;
}
