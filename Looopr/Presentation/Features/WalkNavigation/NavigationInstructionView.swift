import SwiftUI

/// Apple Maps-inspired navigation instruction card.
/// Shows the current turn direction prominently with distance and street name,
/// plus a preview of the next instruction below.
struct NavigationInstructionView: View {
    let instruction: String
    let nextInstruction: String?
    let distanceToNext: Double
    let stepIndex: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 0) {
            // Primary instruction - large, Apple Maps style
            HStack(spacing: 14) {
                // Large direction arrow
                Image(systemName: directionIcon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56)

                VStack(alignment: .leading, spacing: 4) {
                    // Distance prominently displayed
                    Text(formattedDistance)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    // Street/instruction name
                    Text(streetName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6).opacity(0.25))

            // Next instruction preview
            if let next = nextInstruction {
                HStack(spacing: 10) {
                    Image(systemName: directionIcon(for: next))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 28)

                    Text(next)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .background(.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var formattedDistance: String {
        distanceToNext.formattedDistance()
    }

    private var streetName: String {
        // Extract street name from instruction like "Turn left onto Wisselstraat"
        let lower = instruction.lowercased()
        if let range = instruction.range(of: "onto ", options: .caseInsensitive) {
            return String(instruction[range.upperBound...])
        }
        if lower.contains("continue") || lower.contains("proceed") || lower.contains("head") {
            return instruction
        }
        return instruction
    }

    private var directionIcon: String {
        directionIcon(for: instruction)
    }

    private func directionIcon(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("sharp left") || lower.contains("sharply left") { return "arrow.turn.up.left" }
        if lower.contains("sharp right") || lower.contains("sharply right") { return "arrow.turn.up.right" }
        if lower.contains("slight left") || lower.contains("bear left") { return "arrow.up.left" }
        if lower.contains("slight right") || lower.contains("bear right") { return "arrow.up.right" }
        if lower.contains("left") { return "arrow.turn.up.left" }
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("u-turn") || lower.contains("uturn") { return "arrow.uturn.down" }
        if lower.contains("arrive") || lower.contains("destination") { return "flag.fill" }
        if lower.contains("roundabout") || lower.contains("rotary") { return "arrow.triangle.turn.up.right.circle" }
        return "arrow.up"
    }
}
