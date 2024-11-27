//
//  NetworkProvider.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import UIKit

// MARK: - Network Provider
final class NetworkProvider: NetworkProviding {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.decoder = decoder
    }
    
    public func request<T: Decodable>(_ endpoint: NetworkTargetType) async throws -> T {
        let request = try buildRequest(from: endpoint)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding Error: \(error)")
            throw NetworkError.decodingError
        }
    }
    
    func fetchImage(from urlString: String) async throws -> UIImage {
        if let cachedImage = await ImageCache.shared.image(for: urlString) {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(0)
        }
        
        guard let image = UIImage(data: data) else {
            throw NetworkError.decodingError
        }
        
        await ImageCache.shared.insertImage(image, for: urlString)
        return image
    }
    
    private func buildRequest(from endpoint: NetworkTargetType) throws -> URLRequest {
        var urlComponents = URLComponents(string: endpoint.baseURL + endpoint.path)
        
        switch endpoint.task {
        case .requestPlain:
            break
        case .requestParameters(let parameters):
            urlComponents?.queryItems = parameters.map {
                URLQueryItem(name: $0.key, value: String(describing: $0.value))
            }
        }
        
        guard let url = urlComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers
        
        return request
    }
}
