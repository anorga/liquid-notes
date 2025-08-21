//
//  GiphyPicker.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/21/25.
//

import SwiftUI
import UIKit

struct GiphyPicker: View {
    @Binding var isPresented: Bool
    let onGifSelected: (Data) -> Void
    
    @State private var searchText = ""
    @State private var gifs: [GiphyGIF] = []
    @State private var isLoading = false
    @StateObject private var giphyService = GiphyService.shared
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search GIFs...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            searchGifs()
                        }
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                            gifs = []
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                
                // Trending/Search results
                if isLoading {
                    ProgressView("Loading GIFs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(gifs, id: \.id) { gif in
                                AsyncImage(url: gif.previewURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .aspectRatio(1, contentMode: .fit)
                                }
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectGif(gif)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add GIF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                loadTrendingGifs()
            }
        }
    }
    
    private func searchGifs() {
        isLoading = true
        giphyService.searchGifs(query: searchText) { results in
            gifs = results
            isLoading = false
        }
    }
    
    private func loadTrendingGifs() {
        isLoading = true
        giphyService.getTrendingGifs { results in
            gifs = results
            isLoading = false
        }
    }
    
    private func selectGif(_ gif: GiphyGIF) {
        isLoading = true
        // Download GIF data
        URLSession.shared.dataTask(with: gif.gifURL) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data {
                    onGifSelected(data)
                    isPresented = false
                    HapticManager.shared.buttonTapped()
                } else {
                    print("Failed to download GIF: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }.resume()
    }
    
    // Mock data for demo - replace with actual Giphy SDK
    private func mockGifs(for query: String) -> [GiphyGIF] {
        return [
            GiphyGIF(id: "1", previewURL: URL(string: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif")!),
            GiphyGIF(id: "2", previewURL: URL(string: "https://media.giphy.com/media/26BRrSvJUa0crqw4E/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/26BRrSvJUa0crqw4E/giphy.gif")!),
            GiphyGIF(id: "3", previewURL: URL(string: "https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif")!),
            GiphyGIF(id: "4", previewURL: URL(string: "https://media.giphy.com/media/l2JehQ2GitHGdVG9y/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/l2JehQ2GitHGdVG9y/giphy.gif")!)
        ]
    }
    
    private func mockTrendingGifs() -> [GiphyGIF] {
        return [
            GiphyGIF(id: "t1", previewURL: URL(string: "https://media.giphy.com/media/13CoXDiaCcCoyk/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/13CoXDiaCcCoyk/giphy.gif")!),
            GiphyGIF(id: "t2", previewURL: URL(string: "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif")!),
            GiphyGIF(id: "t3", previewURL: URL(string: "https://media.giphy.com/media/26BRrSvJUa0crqw4E/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/26BRrSvJUa0crqw4E/giphy.gif")!),
            GiphyGIF(id: "t4", previewURL: URL(string: "https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif")!),
            GiphyGIF(id: "t5", previewURL: URL(string: "https://media.giphy.com/media/l2JehQ2GitHGdVG9y/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/l2JehQ2GitHGdVG9y/giphy.gif")!),
            GiphyGIF(id: "t6", previewURL: URL(string: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/200.gif")!, gifURL: URL(string: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif")!)
        ]
    }
}

struct GiphyGIF {
    let id: String
    let previewURL: URL
    let gifURL: URL
}