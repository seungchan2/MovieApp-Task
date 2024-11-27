//
//  MovieEndpoint.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import Foundation

enum MovieEndpoint: NetworkTargetType {
    case nowPlaying
    case movieDetail(id: Int)
    
    var baseURL: String {
        return "https://api.themoviedb.org/3"
    }
    
    var path: String {
        switch self {
        case .nowPlaying:
            return "/movie/now_playing"
        case .movieDetail(let id):
            return "/movie/\(id)"
        }
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var task: NetworkTask {
        var parameters: [String: Any] = [
            "api_key": Constants.tmdbAPIKey,
            "language": "ko-KR",
            "region": "KR"
        ]
        
        switch self {
        case .nowPlaying:
            parameters["page"] = "1"
        case .movieDetail:
            break
        }
        
        return .requestParameters(parameters: parameters)
    }
    
    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
}

