import SwiftUI

struct AdminThemesScreen: View {
    @State private var password = ""
    @State private var authenticated = false
    @State private var error: String?
    @StateObject private var paletteManager = PaletteManager.shared

    private let adminPassword = "crazycakes13"

    var body: some View {
        NavigationStack {
            if !authenticated {
                VStack(spacing: 24) {
                    Text("Theme Administration")
                        .font(AppFont.script(28))
                        .foregroundStyle(Palette.primary)

                    if let error = error {
                        Text(error)
                            .font(AppFont.inter(14))
                            .foregroundStyle(.red)
                    }

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(AppFont.inter(14))
                        .frame(maxWidth: 320)

                    Button("Access Themes") {
                        if password == adminPassword {
                            authenticated = true
                        } else {
                            error = "Incorrect password"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.primary)
                }
                .padding()
            } else {
                List {
                    if paletteManager.themes.isEmpty {
                        Text("No themes found.")
                            .font(AppFont.inter(16))
                            .foregroundStyle(Palette.mutedForeground)
                    } else {
                        ForEach(paletteManager.themes) { theme in
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().stroke(theme.borderColor, lineWidth: 1))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(theme.name)
                                            .font(AppFont.interSemiBold(18))
                                            .foregroundStyle(Palette.primary)
                                        Text(theme.isDefault ? "Active (Default)" : "Click to activate")
                                            .font(AppFont.inter(14))
                                            .foregroundStyle(theme.isDefault ? Palette.primary : Palette.mutedForeground)
                                    }

                                    Spacer()

                                    if !theme.isDefault {
                                        Button("Set as Default") {
                                            Task {
                                                await paletteManager.setDefaultTheme(theme)
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Palette.primary)
                                    } else {
                                        Button("Active") {}
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                        .disabled(true)
                                    }
                                }

                                HStack(spacing: 8) {
                                    ColorSwatch(color: theme.primaryColor, label: "Primary")
                                    ColorSwatch(color: theme.secondaryColor, label: "Secondary")
                                    ColorSwatch(color: theme.background, label: "Background")
                                    ColorSwatch(color: theme.muted, label: "Muted")
                                    ColorSwatch(color: theme.gold, label: "Gold")
                                }
                            }
                            .padding(.vertical, 8)
                        }
                }
                .navigationTitle("Theme Administration")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Logout") {
                            authenticated = false
                        }
                    }
                }
            }
        }
    }

    private struct ColorSwatch: View {
        let color: Color
        let label: String

        var body: some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Palette.border, lineWidth: 1))
                Text(label)
                    .font(AppFont.inter(10))
                    .foregroundStyle(Palette.mutedForeground)
            }
        }
    }
}