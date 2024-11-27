//
//  NetworkError.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import Foundation

// MARK: - Network Error
@frozen enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(Int)
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .noData:
            return "데이터가 없습니다."
        case .decodingError:
            return "데이터 디코딩에 실패했습니다."
        case .serverError(let statusCode):
            return "서버 에러가 발생했습니다. (상태 코드: \(statusCode))"
        case .networkError(let error):
            return "네트워크 에러가 발생했습니다. (\(error.localizedDescription))"
        case .invalidResponse:
            return "잘못된 응답입니다."
        }
    }
}
