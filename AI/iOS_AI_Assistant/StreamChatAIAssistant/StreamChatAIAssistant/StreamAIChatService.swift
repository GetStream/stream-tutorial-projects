import Foundation

class StreamAIChatService {
    static let shared = StreamAIChatService()

    private let baseURL = "http://localhost:3000"
    private let jsonEncoder = JSONEncoder()

    private let urlSession = URLSession.shared

    func setupAgent(channelId: String) async throws {
        try await executePostRequest(
            body: AIAgentRequest(channelId: channelId, platform: "openai"),
            endpoint: "start-ai-agent"
        )
    }

    func stopAgent(channelId: String) async throws {
        try await executePostRequest(
            body: AIAgentRequest(channelId: channelId),
            endpoint: "stop-ai-agent"
        )
    }

    private func executePostRequest<RequestBody: Encodable>(body: RequestBody, endpoint: String)
        async throws
    {
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(body)
        _ = try await urlSession.data(for: request)
    }

}

struct AIAgentRequest: Encodable {
    let channelId: String
    let platform: String?

    init(channelId: String, platform: String? = nil) {
        self.channelId = channelId
        self.platform = platform
    }

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case platform
    }
}
