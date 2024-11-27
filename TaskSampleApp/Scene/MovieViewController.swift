//
//  ViewController.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/26/24.
//

import UIKit

@MainActor
class MovieViewController: UIViewController {
    private let viewModel: MovieViewModel
    private var movies: [Movie] = []
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MovieCell.self, forCellReuseIdentifier: MovieCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    init(viewModel: MovieViewModel? = nil) {
        self.viewModel = viewModel ?? MovieViewModel()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.fetchMoviesWithAsyncLet()
    }
    
    private func setupUI() {
        title = "현재 상영작"
        view.backgroundColor = .systemBackground
        
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        setupRefreshControl()
    }
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    @objc private func refreshData() {
        viewModel.fetchMoviesWithAsyncLet()
    }
    
    private func bindViewModel() {
        viewModel.stateDidChange = { [weak self] state in
            Task { @MainActor in
                self?.handleState(state)
            }
        }
    }
    
    private func handleState(_ state: MovieViewModel.State) {
        switch state {
        case .idle:
            loadingIndicator.stopAnimating()
            tableView.refreshControl?.endRefreshing()
        case .loading:
            loadingIndicator.startAnimating()
        case .success(let movies):
            loadingIndicator.stopAnimating()
            tableView.refreshControl?.endRefreshing()
            self.movies = movies
            tableView.reloadData()
        case .failure(let error):
            loadingIndicator.stopAnimating()
            tableView.refreshControl?.endRefreshing()
            showError(error)
        }
    }
    
    private func showError(_ error: Error) {
        let message: String
        if let networkError = error as? NetworkError {
            message = networkError.errorDescription ?? "알 수 없는 에러가 발생했습니다."
        } else {
            message = error.localizedDescription
        }
        
        let alert = UIAlertController(
            title: "에러",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "재시도", style: .default) { [weak self] _ in
            self?.viewModel.fetchMoviesWithAsyncLet()
        })
        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
        present(alert, animated: true)
    }
}

extension MovieViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MovieCell.identifier, for: indexPath) as! MovieCell
        cell.configure(with: movies[indexPath.row])
        return cell
    }
}
