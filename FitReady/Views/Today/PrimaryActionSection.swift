import SwiftUI

/// Legacy action card — superseded by TodayHeroSection which now includes the CTAs inline.
/// Kept in project to avoid removing from build; body renders nothing.
struct PrimaryActionSection: View {
    @ObservedObject var vm: TodayViewModel
    var body: some View { EmptyView() }
}
