//
//  MovieViewModel.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import UIKit

final class MovieViewModel {
    private let networkService: NetworkProviding
    
    enum State {
        case idle
        case loading
        case success([Movie])
        case failure(Error)
    }
    
    private(set) var state: State = .idle {
        didSet {
            stateDidChange?(state)
        }
    }
    
    var stateDidChange: ((State) -> Void)?
    
    init(networkService: NetworkProviding = NetworkProvider()) {
        self.networkService = networkService
    }
    
    /// Task
    @MainActor
    func fetchMoviesWithTask() {
        Task {
            state = .loading
            do {
                let response: MovieResponse = try await networkService.request(MovieEndpoint.nowPlaying)
                let movieTasks = response.results.map { movie in
                    Task {
                        var posterImage: UIImage?
                        if let posterPath = movie.posterPath {
                            posterImage = try? await networkService.fetchImage(from: Constants.imageBaseURL + posterPath)
                        }
                        
                        return Movie(
                            id: movie.id,
                            title: movie.title,
                            overview: movie.overview,
                            posterPath: movie.posterPath,
                            voteAverage: movie.voteAverage,
                            releaseDate: movie.releaseDate,
                            posterImage: posterImage
                        )
                    }
                }
                
                var movies: [Movie] = []
                for task in movieTasks {
                    let movie = await task.value
                    movies.append(movie)
                }
                
                state = .success(movies.sorted { $0.voteAverage > $1.voteAverage })
            } catch {
                state = .failure(error)
            }
        }
    }
    
    /// TaskGroup
    @MainActor
    func fetchMoviesWithTaskGroup() {
        Task {
            state = .loading
            
            do {
                let response: MovieResponse = try await networkService.request(MovieEndpoint.nowPlaying)
                
                let movies = try await withThrowingTaskGroup(of: Movie.self) { group in
                    for movie in response.results {
                        group.addTask { [movie] in
                            var posterImage: UIImage?
                            if let posterPath = movie.posterPath {
                                posterImage = try? await self.networkService.fetchImage(from: Constants.imageBaseURL + posterPath)
                            }
                            
                            return Movie(
                                id: movie.id,
                                title: movie.title,
                                overview: movie.overview,
                                posterPath: movie.posterPath,
                                voteAverage: movie.voteAverage,
                                releaseDate: movie.releaseDate,
                                posterImage: posterImage
                            )
                        }
                    }
                    
                    var movies: [Movie] = []
                    for try await movie in group {
                        movies.append(movie)
                    }
                    return movies.sorted { $0.voteAverage > $1.voteAverage }
                }
                
                state = .success(movies)
            } catch {
                state = .failure(error)
            }
        }
    }
    
    /// Async-let
    /// 주의할 점이 병렬로 동작하지 않는다.
    @MainActor
    func fetchMoviesWithAsyncLet() {
        Task {
            state = .loading
            
            do {
                let response: MovieResponse = try await networkService.request(MovieEndpoint.nowPlaying)
                
                var movies: [Movie] = []
                for movie in response.results {
                    async let posterImage: UIImage? = {
                        if let posterPath = movie.posterPath {
                            return try? await networkService.fetchImage(from: Constants.imageBaseURL + posterPath)
                        }
                        return nil
                    }()
                    
                    let movieWithImage = Movie(
                        id: movie.id,
                        title: movie.title,
                        overview: movie.overview,
                        posterPath: movie.posterPath,
                        voteAverage: movie.voteAverage,
                        releaseDate: movie.releaseDate,
                        posterImage: await posterImage
                    )
                    
                    movies.append(movieWithImage)
                }
                
                state = .success(movies.sorted { $0.voteAverage > $1.voteAverage })
            } catch {
                state = .failure(error)
            }
        }
    }
}
