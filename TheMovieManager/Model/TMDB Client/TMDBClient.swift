//
//  TMDBClient.swift
//  TheMovieManager
//
//  Created by Owen LaRosa on 8/13/18.
//  Copyright © 2018 Udacity. All rights reserved.
//

import Foundation

class TMDBClient {
    
    static let apiKey = "9d7f8d830349f23837b575b8f089e96b"
    
    struct Auth {
        static var accountId = 0
        static var requestToken = ""
        static var sessionId = ""
    }
    
    enum Endpoints {
        static let base = "https://api.themoviedb.org/3"
        static let apiKeyParam = "?api_key=\(TMDBClient.apiKey)"
        
        case getWatchlist
        case getFavorites
        case getRequestToken
        case login
        case createSessionId
        case webAuth
        case logout
        case search(query: String)
        case markWatchlist
        case markFavorite
        
        var stringValue: String {
            switch self {
            case .getWatchlist:
                return Endpoints.base + "/account/\(Auth.accountId)/watchlist/movies" + Endpoints.apiKeyParam + "&session_id=\(Auth.sessionId)"
            case .getFavorites:
                return Endpoints.base + "/account/\(Auth.accountId)/favorite/movies" + Endpoints.apiKeyParam + "&session_id=\(Auth.sessionId)"
            case .search(let query):
                return Endpoints.base + "/search/movie" + Endpoints.apiKeyParam + "&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            case .getRequestToken:
                return Endpoints.base + "/authentication/token/new" + Endpoints.apiKeyParam
            case .login:
                return Endpoints.base + "/authentication/token/validate_with_login" + Endpoints.apiKeyParam
            case .createSessionId:
                return Endpoints.base + "/authentication/session/new" + Endpoints.apiKeyParam
            case .webAuth:
                return "https://www.themoviedb.org/authenticate/" + Auth.requestToken + "?redirect_to=themoviemanager:authenticate"
            case .logout:
                return Endpoints.base + "/authentication/session" + Endpoints.apiKeyParam
            case .markWatchlist:
                return Endpoints.base + "/account/\(Auth.accountId)/watchlist" + Endpoints.apiKeyParam + "&session_id=\(Auth.sessionId)"
            case .markFavorite:
                return Endpoints.base + "/account/\(Auth.accountId)/favorite" + Endpoints.apiKeyParam + "&session_id=\(Auth.sessionId)"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    class func login(username: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        let body = LoginRequest(username: username, password: password, requestToken: Auth.requestToken)
        taskForPOSTRequest(url: Endpoints.login.url, responseType: RequestTokenResponse.self, body: body) { (response, error) in
                            
            guard let responseObject = response else {
                completion(false, error)
                return
            }
            Auth.requestToken = responseObject.requestToken
            completion(true, nil)
        }
    }
    
    class func getNewSession(completion: @escaping(Bool, Error?) -> Void) {
        taskForPOSTRequest(url: Endpoints.createSessionId.url, responseType: SessionResponse.self, body: PostSession(requestToken: Auth.requestToken)) { (response, error) in
            guard let responseObject = response else {
                completion(false, error)
                return
            }
            print("Session Id \(responseObject.sessionId)")
            Auth.sessionId = responseObject.sessionId
            completion(true, nil)
        }
    }
    
    class func getRequestToken(completion: @escaping(Bool, Error?) -> Void) {
        taskForGETRequest(url: Endpoints.getRequestToken.url, responseType: RequestTokenResponse.self) { (response, error) in
            guard let response = response else {
                completion(false, error)
                return
            }
            print("Request Token \(response.requestToken)")
            Auth.requestToken = response.requestToken
            completion(true, nil)
        }
    }
    
    class func markWatchlist(movieId: Int, watchlist: Bool, completion: @escaping(Bool, Error?) -> Void) {
        let body = MarkWatchlist(mediaType: "movie", mediaId: movieId, watchlist: watchlist)
        taskForPOSTRequest(url: Endpoints.markWatchlist.url, responseType: TMDBResponse.self, body: body) {
            (response, error) in
            if let response = response {
                completion(response.statusCode == 1 || response.statusCode == 12 || response.statusCode == 13, nil)
            } else {
                completion(false, error)
            }
        }
    }
    
    class func markFavorite(movieId: Int, favorite: Bool, completion: @escaping(Bool, Error?) -> Void) {
        let body = MarkFavorite(mediaType: "movie", mediaId: movieId, favorite: favorite)
        taskForPOSTRequest(url: Endpoints.markWatchlist.url, responseType: TMDBResponse.self, body: body) {
            (response, error) in
            if let response = response {
                completion(response.statusCode == 1 || response.statusCode == 12 || response.statusCode == 13, nil)
            } else {
                completion(false, error)
            }
        }
    }
    
    class func logout(completion: @escaping(Error?) -> Void) {
        var urlRequest = URLRequest(url: Endpoints.logout.url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let logoutBody = LogoutRequest(sessionId: Auth.sessionId)
        urlRequest.httpBody = try! JSONEncoder().encode(logoutBody)
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            Auth.sessionId = ""
            Auth.requestToken = ""
            Auth.accountId = 0
            
            guard let _ = data else {
                completion(error)
                return
            }
            
            completion(nil)
        }
        task.resume()
    }
    
    class func getWatchlist(completion: @escaping ([Movie], Error?) -> Void) {
        taskForGETRequest(url: Endpoints.getWatchlist.url, responseType: MovieResults.self) { (response, error) in
            guard let responseObject = response else {
                completion([], error)
                return
            }
            completion(responseObject.results, nil)
        }
    }
    
    class func searchMovie(query: String, completion: @escaping ([Movie], Error?) -> Void) {
        taskForGETRequest(url: Endpoints.search(query: query).url, responseType: MovieResults.self) { (response, error) in
            guard let responseObject = response else {
                completion([], error)
                return
            }
            completion(responseObject.results, nil)
        }
    }
    
    class func getFavorites(completion: @escaping ([Movie], Error?) -> Void) {
        taskForGETRequest(url: Endpoints.getFavorites.url, responseType: MovieResults.self) { (response, error) in
            guard let responseObject = response else {
                completion([], error)
                return
            }
            completion(responseObject.results, nil)
        }
    }
    
    class func taskForGETRequest<ResponseType: Decodable>(url: URL, responseType: ResponseType.Type,
                                                          completion: @escaping (ResponseType?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            let decoder = JSONDecoder()
            do {
                let responseObject = try decoder.decode(ResponseType.self, from: data)
                DispatchQueue.main.async {
                    completion(responseObject, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        task.resume()
        
    }

    class func taskForPOSTRequest<RequestType: Encodable, ResponseType: Decodable>(url: URL, responseType: ResponseType.Type, body: RequestType,
                                                                                   completion: @escaping (ResponseType?, Error?) -> Void) {
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try! JSONEncoder().encode(body)
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
        
            do {
                let responseObject = try JSONDecoder().decode(ResponseType.self, from: data)
                DispatchQueue.main.async {
                    completion(responseObject, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        task.resume()
    }

}
