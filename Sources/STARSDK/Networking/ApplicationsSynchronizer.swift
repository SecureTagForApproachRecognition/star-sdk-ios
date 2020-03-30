//

import Foundation

/// Fetch the discovery data and stores it
class ApplicationSynchronizer {
    /// The storage of the data
    let storage: ApplicationStorage
    /// The enviroment
    let enviroment: Enviroment

    /// Create a synchronizer
    /// - Parameters:
    ///   - enviroment: The environment of the synchronizer
    ///   - storage: The storage
    init(enviroment: Enviroment, storage: ApplicationStorage) {
        self.storage = storage
        self.enviroment = enviroment
    }

    /// Synchronize the local and remote data.
    /// - Parameter callback: A callback with the sync result
    func sync(callback: @escaping (Result<Void, STARTracingErrors>) -> Void) throws {
        ExposeeServiceClient.getAvailableApplicationDescriptors(enviroment: enviroment) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(ad):
                do {
                    try ad.forEach(self.storage.add(appDescriptor:))
                    callback(.success(()))
                } catch {
                    callback(.failure(STARTracingErrors.DatabaseError(error: error)))
                }
            case let .failure(error):
                callback(.failure(STARTracingErrors.NetworkingError(error: error)))
            }
        }
    }
}
