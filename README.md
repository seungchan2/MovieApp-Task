# TMDB API를 사용한 Task, TaskGroup, Async-let 성능 비교
## 들어가며
> TMDB API를 사용하여 영화 정보를 가져와 화면에 보여준다.
> 
> Task TaskGroup Async-let 세 가지 방법을 Instruments 통해 비교해보려고 한다.
> 
> 다만 Async-let은 병렬로 동작하지 않는데 그 이유는 밑에서 설명하겠다.
 
## 1. Task
```swift
/// MovieViewModel 내 fetchMoviesWithTask()
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
```
> 해당 코드가 Instruments에서 어떻게 동작할 지 유추해보겠다.

### 1.1 Task 코드 동작 흐름
1. **메인 Task 생성**
- 초기 Task가 생성되고 `state = .loading` 설정한다.
- `networkService.request` 호출하고, 이 부분은 하나의 Task 스트림으로 표시될 것이다.
2. **여러 개의 독립적인 Task 생성**
- `response.results.map`에서 각 영화마다 새로운 Task 생성할 것이다.
- 예를 들어 20개의 영화가 있다면, 20개의 독립적인 Task 스트림이 동시에 생성한다.
- 각 Task는 이미지 다운로드를 수행할 것이다.
3. **Task의 병렬 실행**
- 생성된 모든 Task가 동시에 실행할 것이다.
- 다만 시스템 리소스와 네트워크 상황에 따라 실제 동시 실행되는 Task 수는 제한될 수 있을 것이다.
4. **결과 수집 단계**
- `for task in movieTasks` 루프에서 각 Task의 완료를 기다릴 것이다.
- Task들이 완료되는 순서대로 결과가 수집되며, 이 과정에서 Task 스트림들이 순차적으로 종료되는 것이 보일 것이다.

### 1.2 Task Instrumenst-Swift Concurrency
<img width="709" alt="스크린샷 2024-11-27 오후 1 40 00" src="https://github.com/user-attachments/assets/6bdeac98-d616-43d6-af62-996b919c9da1">

> `viewDidLoad()` 에서 `fetchMoviesWithTask`가 호출되었고, 20개의 Task가 생성되어 `Creating - Running - Suspend .. - Continuation - Suspend - Running -..` 의 과정으로 진행되는 것을 확인할 수 있다.
>
> Task 내 `Continuation`은 `URLSession`을 통해 네트워크 통신을 하면서 생성된 것이다.
>
> 그렇다면 해당 코드가 병렬처럼 동작하는 이유는 무엇일까?
- 그 이유는 `map` 함수를 사용하여 각 영화마다 개별 Task를 생성했기 때문이다.
- map 함수로 인해 `response.results` 배열의 각 요소인 movie에 대해 클로저를 호출하고 새로운 Task를 생성한다. (배열의 원소 갯수만큼 독립적인 Task 생성)
- 그로인해 Task 작업들이 병렬로 처리되는 것 같이 보인다.
- 이후 `for 루프`에서는 movieTasks 배열의 각 Task에 대해 `await` 키워드를 사용하여 해당 Task의 결과`(task.value)`를 기다린다.
- `await` 키워드는 해당 Task가 완료될 때까지 기다리지만, 다른 Task들은 계속 실행될 수 있다.
- 아래의 사진은 GCD처럼 매번 스레드를 생성하지 않고, 하나의 스레드에서 여러 Task들이 처리될 수 있음을 보여준다.
- 간단히 정리하자면, `fetchMoviesWithTask()` 내, 최상단 Task가 `await`을 통헤 `task.value`를 받을 때 까지, `Waiting` 상태를 가지며 이 상태동안 각 Task들이 이미지를 가져오는 작업을 가진다.

<img width="709" alt="스크린샷 2024-11-27 오후 1 52 36" src="https://github.com/user-attachments/assets/eb232108-58b2-426f-aa5b-3cf5fc519f4a">

## 2. TaskGroup
```swift
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
``` 

> TaskGroup이 Instruments에서 어떻게 동작할 지 유추해보겠다.

### 2.1 TaskGroup 코드 동작 흐름
1. **메인 Task 생성**
- Task 블록이 시작되고 state = .loading 설정한다.
- networkService.request로 영화 목록을 호출하고, 이는 단일 Task 스트림으로 표시될 것이다.

2. TaskGroup 생성과 작업 추가
- withThrowingTaskGroup으로 Task들을 관리할 그룹을 생성한다.
- response.results의 각 영화에 대해 group.addTask를 통해 작업을 추가한다.
- 이때 캡처 리스트 [movie]를 사용하여 각 Task가 독립적으로 동작하도록 보장한다.
3. 병렬 실행과 시스템 관리
- TaskGroup 내의 모든 작업들이 시스템에 의해 관리되며 동시에 실행된다.
- 시스템이 Thread Pool을 통해 자동으로 동시성을 최적화한다.
- 각 Task에서는 이미지 다운로드와 Movie 객체 생성을 수행한다.
4. 결과 수집과 정렬
- for try await movie in group에서 완료되는 순서대로 결과를 수집한다.
- 수집된 결과들을 배열에 추가하고, 평점순으로 정렬한다.
- 모든 작업이 완료되면 state = .success(movies)로 상태를 업데이트한다.

> TaskGroup의 핵심은 부모의 작업은 자식의 작업이 마칠 때까지 기다렸다가 동작하는 것인데 Instruments를 통해 확인해보겠다.

### 1.2 Task Instrumenst-Swift Concurrency
<img width="709" alt="image" src="https://github.com/user-attachments/assets/09776df8-692f-4583-90f5-fb6e1a7983ba">

> 실제 Instruments를 살펴보면 fetchMovieWithTaskGroup()이 호출되고, 부모의 작업은 자식들의 작업이 마칠 때까지 기다린다.
- Task에서와 for 루프와 달리 for try await 루프를 사용했다.
- 해당 for try await을 통해 TaskGroup의 작업들이 완료되는 순서대로 결과를 가져온다.
- 말그대로 병렬이기 때문에 어떤 작업이 먼저 실행되고, 먼저 마치는 지 알 수 없다.

- Task와 다르게 자식 작업들은 Suspend 과정이 생략된 것이 보인다. (Continuation 이전)

- Task의 suspend
  - 각 Task의 결과를 await task.value로 직접 기다린다.
  - 한 Task가 완료될 때까지 suspend되고, 그 다음 Task로 넘어가기 때문이다.
  - 이 과정에서 suspend가 발생한다.
   
- TaskGroup
  - 시스템 레벨에서 최적화된 동시성 처리하며, 개별적인 suspend 없이 결과가 준비되는 대로 처리한다.

- 즉, TaskGroup은 Swift 런타임이 제공하는 최적화된 동시성 관리를 사용하기 때문에 불필요한 suspend가 발생하지 않는다.

  
## Async-let
> Async-let에 들어가기 앞서, 해당 코드는 해당 프로젝트에서 병렬로 동작할 수 없다.
>
> 그 이유는 Async-let은 갯수에 대한 보장이 있을 때 사용하는 것이 적합하다.
>
> 하지만 해당 API는 영화 데이터에 대한 명확한 갯수없이 가져오기 때문에 컴파일 시점에 작업 수를 알 수 없다.
> 
> 또한 for 루프 안에서 각 posterImage를 await하기 때문에 이전 작업이 완료되어야 다음 작업이 진행된다.
>
> 따라서 Async-let을 사용했지만 실제로는 순차적으로 실행될 것이다.
```swift
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
```
### 1.2 Async-let Instrumenst-Swift Concurrency
<img width="709" alt="image" src="https://github.com/user-attachments/assets/fb90023b-a4d2-452f-85ee-dacc6c2871a0">


## Task, TaskGroup, Async-let 메모리 및 이미지 다운로드 시간 비교
> 먼저 `CFAbsoluteTimeGetCurrent`를 사용해서 각 메소드 별 얼마나 걸리는 지 확인해보았다.

> 결과를 확인하기 전, `TaskGroup` `Task` `Async-let` 순으로 시간이 빠를 것으로 생각했다.
```swift
/// Task
이미지 다운로드 시간: 0.96초
전체 작업 시간(Task): 1.19초

/// TaskGroup
API 요청 시간: 0.35초
전체 작업 시간(TaskGroup): 0.38초

/// Async-let
API 요청 시간: 0.38초
전체 작업 시간(async-let): 0.45초
```
- 하지만 결과에서는 `TaskGroup` `Async-let` `Task` 순서인 것을 확인할 수 있었다.
- `TaskGroup`은 병렬 처리가 되고 있어 `Task` 생성과 실행 오버헤드가 최소화 되므로 가장 빠름을 보장한다. (해당 프로젝트 내에서는)

> 그렇다면 `async-let`이 `Task`보다 빠르게 작업을 처리하는 이유는 뭘까?
```swift
let moviesWithImages = try await response.results.map { movie in
    async let posterImage: UIImage? = {
        if let posterPath = movie.posterPath {
            return try? await networkService.fetchImage(from: Constants.imageBaseURL + posterPath)
        }
        return nil
    }()
}
```
- `async-let`은 이미지 로드가 시작되고, 바로 다음 이미지 로드도 시작된다.

- Task는 매번 새로운 Task를 생성함으로써 오버헤드가 발생하고, for 루프 내 순차적인 대기가 발생한다.
- `async-let` 또한 순차적인 작업을 하고 있지만, **async-let의 순차적인 작업 >>> Task** 매번 생성보다 오버헤드가 적기 때문에 시간 차이가 발생하는 것 같다.

  



