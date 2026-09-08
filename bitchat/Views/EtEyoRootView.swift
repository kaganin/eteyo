//
//  EtEyoRootView.swift
//  bitchat
//
//  The new eteyo navigation shell. The existing bitchat interface remains
//  available as a development reference from the Debug tab.
//

import SwiftUI

#if os(iOS)
struct EtEyoRootView: View {
    private enum Tab: Hashable {
        case locations
        case chats
        case settings
        #if DEBUG
        case debug
        #endif
    }

    @State private var selectedTab: Tab = .locations
    @StateObject private var conversationStore = EtEyoConversationStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            EtEyoLocationsScreen()
                .tabItem {
                    Label("Locations", systemImage: "location")
                }
                .tag(Tab.locations)

            EtEyoChatsScreen()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(Tab.chats)

            EtEyoPlaceholderScreen(title: "settings")
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)

            #if DEBUG
            ContentView()
                .tabItem {
                    Label("Debug", systemImage: "wrench.and.screwdriver")
                }
                .tag(Tab.debug)
            #endif
        }
        .tint(.accentColor)
        .preferredColorScheme(.dark)
        .environmentObject(conversationStore)
    }
}

private struct EtEyoChatsScreen: View {
    @EnvironmentObject private var store: EtEyoConversationStore
    private let rows = [
        EtEyoChatRowData(id: 0, name: "@anon2714", message: "Message goes here", time: "20:30", color: Color(red: 1, green: 2 / 255, blue: 45 / 255)),
        EtEyoChatRowData(id: 1, name: "@anon2714", message: "Message goes here", time: "20:30", color: Color(red: 1, green: 201 / 255, blue: 0)),
        EtEyoChatRowData(id: 2, name: "@anon2714", message: "Message goes here", time: "20:30", color: Color(red: 0, green: 202 / 255, blue: 72 / 255)),
        EtEyoChatRowData(id: 3, name: "@anon2714", message: "Message goes here", time: "20:30", color: Color(red: 0, green: 204 / 255, blue: 179 / 255))
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                EtEyoScreenTitle("chats")
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            NavigationLink {
                                EtEyoConversationScreen(destination: .person(row.id, row.name), color: row.color)
                            } label: {
                                EtEyoChatRow(row: displayedRow(row))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("eteyo.chat.\(row.id)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground))
        }
    }

    private func displayedRow(_ row: EtEyoChatRowData) -> EtEyoChatRowData {
        guard let last = store.draft(for: .person(row.id, row.name)).messages.last else { return row }
        return EtEyoChatRowData(id: row.id, name: row.name, message: last.text,
                               time: last.date.formatted(date: .omitted, time: .shortened), color: row.color)
    }
}

private struct EtEyoChatRowData: Identifiable {
    let id: Int
    let name: String
    let message: String
    let time: String
    let color: Color
}

private struct EtEyoChatRow: View {
    let row: EtEyoChatRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(row.name)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(row.color)
                    .tracking(0.2)
                    .frame(height: 18, alignment: .center)

                Spacer(minLength: 8)

                Text(row.time)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(height: 16, alignment: .center)
            }
            .frame(height: 18)

            Text(row.message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 16)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct EtEyoLocationsScreen: View {
    private let rows = [
        EtEyoLocationRowData(
            title: "mesh",
            people: "1 person",
            detail: "50 m  ·  bluetooth",
            isActive: true
        ),
        EtEyoLocationRowData(
            title: "block",
            people: "? people",
            detail: "0.2 km  ·  Neukölln"
        ),
        EtEyoLocationRowData(
            title: "neighbourhood",
            people: "? people",
            detail: "0.2 km  ·  Neukölln"
        ),
        EtEyoLocationRowData(
            title: "city",
            people: "1 person",
            detail: "0.2 km  ·  Neukölln"
        ),
        EtEyoLocationRowData(
            title: "province",
            people: "2 people",
            detail: "0.2 km  ·  Neukölln"
        ),
        EtEyoLocationRowData(
            title: "region",
            people: "6 people",
            detail: "0.2 km  ·  Neukölln"
        )
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                EtEyoScreenTitle("locations")
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            NavigationLink {
                                EtEyoConversationScreen(destination: .location(row.title), color: .accentColor, participantSummary: row.people)
                            } label: {
                                EtEyoLocationRow(row: row)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("eteyo.location.\(row.title)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground))
        }
    }
}

private struct EtEyoLocationRowData: Identifiable {
    let title: String
    let people: String
    let detail: String
    var isActive = false

    var id: String { title }
}

private struct EtEyoLocationRow: View {
    let row: EtEyoLocationRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(row.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(row.isActive ? Color(red: 0, green: 130 / 255, blue: 252 / 255) : .primary)
                    .tracking(0.2)
                    .frame(height: 18, alignment: .center)

                Spacer(minLength: 8)

                Text(row.people)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(height: 16, alignment: .center)
            }
            .frame(height: 18)

            Text(row.detail)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 16)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct EtEyoScreenTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 30, weight: .light))
            .tracking(0.5)
            .frame(height: 44, alignment: .leading)
            .padding(.horizontal, 20)
    }
}

private struct EtEyoPlaceholderScreen: View {
    let title: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                EtEyoScreenTitle(title)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground))
        }
    }
}
#endif
