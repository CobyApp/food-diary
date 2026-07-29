import AVFoundation
import Dependencies
import DependenciesMacros
import Foundation

public enum CameraAccess: Equatable, Sendable {
    case granted
    /// Refused, and iOS will not ask again — only Settings can change it.
    case denied
}

/// Asks for the camera, once.
///
/// iOS shows its prompt a single time: after a refusal `requestAccess` returns
/// false without any prompt appearing, so an app cannot ask again. All that is
/// left is to say so and offer to open Settings.
@DependencyClient
public struct CameraAccessClient: Sendable {
    public var request: @Sendable () async -> CameraAccess = { .denied }
}

extension CameraAccessClient: DependencyKey {
    public static let liveValue = CameraAccessClient(
        request: {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                return .granted
            case .notDetermined:
                return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
            case .denied, .restricted:
                return .denied
            @unknown default:
                return .denied
            }
        }
    )
}

extension CameraAccessClient: TestDependencyKey {
    public static let testValue = CameraAccessClient()
    public static let previewValue = CameraAccessClient(request: { .granted })
}

public extension DependencyValues {
    var cameraAccess: CameraAccessClient {
        get { self[CameraAccessClient.self] }
        set { self[CameraAccessClient.self] = newValue }
    }
}
