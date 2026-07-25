import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class CollectionFeatureTests: XCTestCase {
    @MainActor
    func test_onAppear_loadsCutouts() async {
        let sample = [
            CutoutSnapshot(id: UUID(), fileName: "a.png", createdAt: Date(), label: "라멘"),
        ]
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { sample }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.cutoutsLoaded) {
            $0.isLoading = false
            $0.cutouts = sample
        }
    }

    @MainActor
    func test_multiSelect_thenDelete_removesOnlySelectedCutouts() async {
        let first = CutoutSnapshot(
            id: UUID(), fileName: "first.png", createdAt: Date(), label: nil
        )
        let second = CutoutSnapshot(
            id: UUID(), fileName: "second.png", createdAt: Date(), label: nil
        )
        var initialState = CollectionFeature.State()
        initialState.cutouts = [first, second]
        let store = TestStore(initialState: initialState) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.deleteCutouts = { ids in
                XCTAssertEqual(ids, [first.id])
            }
        }

        await store.send(.editButtonTapped) {
            $0.isEditing = true
        }
        await store.send(.selectionToggled(first.id)) {
            $0.selectedCutoutIDs = [first.id]
        }
        await store.send(.deleteSelectedConfirmed) {
            $0.isDeleting = true
        }
        await store.receive(\.cutoutsDeleted) {
            $0.cutouts = [second]
            $0.selectedCutoutIDs = []
            $0.isDeleting = false
            $0.isEditing = false
        }
    }

    @MainActor
    func test_selectAll_togglesEveryCutout() async {
        let cutouts = [
            CutoutSnapshot(id: UUID(), fileName: "a.png", createdAt: Date(), label: nil),
            CutoutSnapshot(id: UUID(), fileName: "b.png", createdAt: Date(), label: nil),
        ]
        var initialState = CollectionFeature.State()
        initialState.cutouts = cutouts
        initialState.isEditing = true
        let store = TestStore(initialState: initialState) {
            CollectionFeature()
        }

        await store.send(.selectAllTapped) {
            $0.selectedCutoutIDs = Set(cutouts.map(\.id))
        }
        await store.send(.selectAllTapped) {
            $0.selectedCutoutIDs = []
        }
    }

    @MainActor
    func test_onAppear_whenLoadFails_clearsLoadingAndShowsEmpty() async {
        struct LoadError: Error {}
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { throw LoadError() }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.cutoutsLoaded) {
            $0.isLoading = false
            $0.cutouts = []
        }
    }

    @MainActor
    func test_achievementsButton_presentsAndDismisses() async {
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.achievementsButtonTapped) {
            $0.achievements = AchievementsFeature.State()
        }
        await store.send(.achievements(.presented(.close))) {
            $0.achievements = nil
        }
    }

    @MainActor
    func test_recapButton_presentsAndDismisses() async {
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.recapButtonTapped) {
            $0.recap = RecapFeature.State()
        }
        await store.send(.recap(.presented(.close))) {
            $0.recap = nil
        }
    }

    @MainActor
    func test_profileCheck_presentsOnboardingForNewUser() async {
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.profileSettings.load = { ProfileSnapshot() }
        }

        await store.send(.profileCheck)
        await store.receive(\.profileLoaded) {
            $0.profile = ProfileFeature.State(profile: ProfileSnapshot(), isOnboarding: true)
        }
    }

    @MainActor
    func test_profileButton_opensCompletedProfile() async {
        let profile = ProfileSnapshot(
            name: "푸디", avatar: "ribbon", favoriteFood: "라멘", hasCompletedOnboarding: true
        )
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.profileSettings.load = { profile }
        }

        await store.send(.profileButtonTapped)
        await store.receive(\.profileEditorLoaded) {
            $0.profile = ProfileFeature.State(profile: profile)
        }
    }
}
