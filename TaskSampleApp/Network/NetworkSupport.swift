//
//  NetworkTargetType.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import UIKit

// MARK: - Network Service
protocol NetworkTargetType {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: NetworkTask { get }
    var headers: [String: String]? { get }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - Network Task
enum NetworkTask {
    case requestPlain
    case requestParameters(parameters: [String: Any])
}

// MARK: - Network Provider Protocol
protocol NetworkProviding {
    func request<T: Decodable>(_ endpoint: NetworkTargetType) async throws -> T
    func fetchImage(from urlString: String) async throws -> UIImage
}
