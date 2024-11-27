# TMDB API를 사용한 Task, TaskGroup, Async-let 성능 비교
## 들어가며
> TMDB API를 사용하여 영화 정보를 가져와 화면에 보여준다.
> Task TaskGroup Async-let 세 가지 방법을 Instruments 통해 비교해보려고 한다.
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

## TaskGroup

## Async-let
