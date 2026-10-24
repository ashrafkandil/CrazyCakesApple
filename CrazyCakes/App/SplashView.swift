import SwiftUI

/// The launch splash - the native twin of the boot state in App.tsx.
struct SplashView: View {
    var loading: Bool

    var body: some View {
        ZStack {
            Palette.footer.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Color.white)
                    LocalImage(
                        src: "/assets/crazy/logo.png",
                        contentDescription: "Marwa Crazy Cakes",
                        contentMode: .fit
                    )
                    .frame(width: 120, height: 120)
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())

                Text("Marwa Crazy Cakes")
                    .font(AppFont.script(40))
                    .foregroundStyle(Palette.primaryForeground)
                    .multilineTextAlignment(.center)
                    .padding(.top, 26)

                Text("Edible art. Unforgettable moments.")
                    .font(AppFont.serif(11))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.footerAlpha(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                if loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Palette.primaryForeground))
                        .padding(.top, 28)
                }
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }
}

/// The "Something went wrong" state from App.tsx, with a retry that re-runs bootstrap.
struct BootstrapErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            Palette.footer.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Something went wrong")
                    .font(AppFont.script(30))
                    .foregroundStyle(Palette.primaryForeground)

                Text(message)
                    .font(AppFont.inter(14))
                    .lineSpacing(8)
                    .foregroundStyle(Palette.footerAlpha(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 32)

                Button(action: retry) {
                    Text("Retry")
                        .font(AppFont.interMedium(15))
                        .foregroundStyle(Palette.primaryForeground)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 26)
                        .background(Capsule().fill(Palette.primary))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
}
