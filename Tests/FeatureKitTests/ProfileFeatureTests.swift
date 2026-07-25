import ComposableArchitecture
import Models
import XCTest
@testable import FeatureKit

final class ProfileFeatureTests: XCTestCase {
    @MainActor
    func test_saveCompletesOnboarding() async {
        let saved = LockIsolated<ProfileSnapshot?>(nil)
        let store = TestStore(
            initialState: ProfileFeature.State(isOnboarding: true)
        ) {
            ProfileFeature()
        } withDependencies: {
            $0.profileSettings.save = { saved.setValue($0) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nameChanged("푸디")) { $0.name = "푸디" }
        await store.send(.avatarSelected("ribbon")) { $0.avatar = "ribbon" }
        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.saved) { $0.isSaving = false }

        XCTAssertEqual(saved.value?.name, "푸디")
        XCTAssertEqual(saved.value?.avatar, "ribbon")
        XCTAssertEqual(saved.value?.hasCompletedOnboarding, true)
    }
}
