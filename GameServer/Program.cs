using GameServer.Core;

class Program
{
    static async Task Main(string[] args)
    {
        var server = new Server(8082);
        await server.Run();
    }
}
