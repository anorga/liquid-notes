//
//  GiphyService.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/21/25.
//

import Foundation
import UIKit
import Combine

class GiphyService: ObservableObject {
    static let shared = GiphyService()
    
    private let apiKey = "your_giphy_api_key_here" // Replace with actual Giphy API key
    private let baseURL = "https://api.giphy.com/v1/gifs"
    
    private init() {}
    
    func searchGifs(query: String, completion: @escaping ([GiphyGIF]) -> Void) {
        guard !query.isEmpty else {
            getTrendingGifs(completion: completion)
            return
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search?api_key=\(apiKey)&q=\(encodedQuery)&limit=20&rating=g"
        
        performRequest(urlString: urlString, completion: completion)
    }
    
    func getTrendingGifs(completion: @escaping ([GiphyGIF]) -> Void) {
        let urlString = "\(baseURL)/trending?api_key=\(apiKey)&limit=20&rating=g"
        performRequest(urlString: urlString, completion: completion)
    }
    
    private func performRequest(urlString: String, completion: @escaping ([GiphyGIF]) -> Void) {
        // For demo purposes, return mock data
        // In production, replace with actual Giphy API calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(self.getMockGifs())
        }
        
        /* Uncomment for real Giphy API integration:
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            do {
                let giphyResponse = try JSONDecoder().decode(GiphyResponse.self, from: data)
                let gifs = giphyResponse.data.map { gif in
                    GiphyGIF(
                        id: gif.id,
                        previewURL: URL(string: gif.images.fixedHeight.url)!,
                        gifURL: URL(string: gif.images.original.url)!
                    )
                }
                DispatchQueue.main.async {
                    completion(gifs)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
        */
    }
    
    private func getMockGifs() -> [GiphyGIF] {
        return [
            GiphyGIF(id: "1", previewURL: URL(string: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif")!),
            GiphyGIF(id: "2", previewURL: URL(string: "https://media.giphy.com/media/26BRrSvJUa0crqw4E/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/26BRrSvJUa0crqw4E/giphy.gif")!),
            GiphyGIF(id: "3", previewURL: URL(string: "https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif")!),
            GiphyGIF(id: "4", previewURL: URL(string: "https://media.giphy.com/media/l2JehQ2GitHGdVG9y/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/l2JehQ2GitHGdVG9y/giphy.gif")!),
            GiphyGIF(id: "5", previewURL: URL(string: "https://media.giphy.com/media/13CoXDiaCcCoyk/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/13CoXDiaCcCoyk/giphy.gif")!),
            GiphyGIF(id: "6", previewURL: URL(string: "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif")!)
        ]
    }
}

// MARK: - Giphy API Response Models (for future real API integration)
struct GiphyResponse: Codable {
    let data: [GiphyAPIGif]
}

struct GiphyAPIGif: Codable {
    let id: String
    let images: GiphyImages
}

struct GiphyImages: Codable {
    let original: GiphyImageData
    let fixedHeight: GiphyImageData
    
    private enum CodingKeys: String, CodingKey {
        case original
        case fixedHeight = "fixed_height"
    }
}

struct GiphyImageData: Codable {
    let url: String
}