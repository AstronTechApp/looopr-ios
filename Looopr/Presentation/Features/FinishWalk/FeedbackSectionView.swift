import SwiftUI

struct FeedbackSectionView: View {
    @Binding var rating: Int
    @Binding var selectedTags: Set<String>
    @Binding var comment: String
    let accentColor: Color
    let onToggleTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            Text(L10n.Feedback.howWasWalk)
                .font(AppTheme.headlineFont)
                .padding(.horizontal, AppTheme.spacingMedium)

            // Star rating
            starRating
                .padding(.horizontal, AppTheme.spacingMedium)

            // Tags (only show after rating)
            if rating > 0 {
                tagSection
                    .transition(.opacity.combined(with: .move(edge: .top)))

                // Optional comment
                commentField
                    .padding(.horizontal, AppTheme.spacingMedium)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: rating)
    }

    // MARK: - Stars

    private var starRating: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.4))
                    .scaleEffect(star <= rating ? 1.1 : 1.0)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            rating = star
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
            Spacer()
        }
    }

    // MARK: - Tags

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if rating >= 3 {
                tagRow(tags: FeedbackTag.positive)
            }
            if rating <= 3 {
                tagRow(tags: FeedbackTag.negative)
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
    }

    private func tagRow(tags: [FeedbackTag]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(tags) { tag in
                tagChip(tag)
            }
        }
    }

    private func tagChip(_ tag: FeedbackTag) -> some View {
        let isSelected = selectedTags.contains(tag.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggleTag(tag.id)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tag.icon)
                    .font(.caption2)
                Text(tag.label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? accentColor.opacity(0.15) : AppTheme.secondaryBackground)
            .foregroundStyle(isSelected ? accentColor : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comment

    private var commentField: some View {
        TextField("Add a note (optional)", text: $comment)
            .font(.subheadline)
            .padding(AppTheme.spacingSmall)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

// MARK: - Flow Layout

/// A simple wrapping layout for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
