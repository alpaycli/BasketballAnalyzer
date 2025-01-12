//
//  PhotoPickerItem+Ext.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 12.01.25.
//

import PhotosUI
import SwiftUI

extension PhotosPickerItem {
    func getURL(completionHandler: @escaping @Sendable (_ result: Result<URL, Error>) -> Void) {
        // Step 1: Load as Data object.
        self.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let contentType = self.supportedContentTypes.first {
                    // Step 2: make the URL file name and a get a file extention.
                    let url = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).\(contentType.preferredFilenameExtension ?? "")")
                    if let data = data {
                        do {
                            // Step 3: write to temp App file directory and return in completionHandler
                            try data.write(to: url)
                            completionHandler(.success(url))
                        } catch {
                            completionHandler(.failure(error))
                        }
                    }
                }
            case .failure(let failure):
                completionHandler(.failure(failure))
            }
        }
    }
}

func getDocumentsDirectory() -> URL {
    // find all possible documents directories for this user
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

    // just send back the first one, which ought to be the only one
    return paths[0]
}
