import ComposableArchitecture
import SwiftUI

public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>
    public init(store: StoreOf<ProfileFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if store.isOnboarding {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("나만의 푸드 다이어리")
                                    .font(.appTitle)
                                    .foregroundStyle(.appInk)
                                Text("먹은 순간을 귀여운 누끼로 모아보세요.")
                                    .font(.appBody)
                                    .foregroundStyle(.appMuted)
                            }
                        }

                        ProfileAvatarView(store.avatar, size: 96)
                            .frame(maxWidth: .infinity)

                        SoftCard {
                            VStack(alignment: .leading, spacing: 16) {
                                field("이름", placeholder: "어떻게 불러드릴까요?", value: Binding(
                                    get: { store.name },
                                    set: { store.send(.nameChanged($0)) }
                                ))
                                Divider()
                                field("최애 음식", placeholder: "예: 라멘", value: Binding(
                                    get: { store.favoriteFood },
                                    set: { store.send(.favoriteFoodChanged($0)) }
                                ))
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("내 캐릭터").font(.appSection).foregroundStyle(.appInk)
                            HStack {
                                ForEach(ProfileAvatarStyle.all) { avatar in
                                    Button { store.send(.avatarSelected(avatar.id)) } label: {
                                        Image(systemName: avatar.symbol)
                                            .font(.title3.bold())
                                            .foregroundStyle(Color.appChocolate)
                                            .frame(width: 43, height: 43)
                                            .background(
                                                ProfileAvatarStyle.resolve(store.avatar).id == avatar.id
                                                    ? avatar.color : Color.appCard,
                                                in: Circle()
                                            )
                                    }
                                    .buttonStyle(KitschPressStyle())
                                }
                            }
                        }

                        PillButton(
                            store.isOnboarding ? "시작하기" : "프로필 저장",
                            enabled: store.canSave && !store.isSaving
                        ) {
                            store.send(.saveTapped)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.text(store.isOnboarding ? "반가워요!" : "내 프로필"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !store.isOnboarding {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") { store.send(.close) }
                    }
                }
            }
        }
        .interactiveDismissDisabled(store.isOnboarding)
    }

    @ViewBuilder
    private func field(_ title: String, placeholder: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(title)).font(.appSection).foregroundStyle(.appInk)
            TextField(L10n.text(placeholder), text: value)
                .font(.appBody)
                .textInputAutocapitalization(.never)
        }
    }
}
