//
//  MovieResponse.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import UIKit

// MARK: - Models
struct MovieResponse: Decodable {
    let results: [Movie]
}

struct Movie: Decodable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let voteAverage: Double
    let releaseDate: String
    var posterImage: UIImage?
    
    private enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
    }
}
