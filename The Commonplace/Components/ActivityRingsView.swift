// ActivityRingsView.swift
// Commonplace
//
// Displays Apple Watch-style concentric activity rings with stat labels.
// Used in journal entry detail views to show HealthKit data for that day.
//
// Rings are decorative — they show a fixed partial fill for visual interest
// since we display raw numbers rather than goal percentages.
//
// Colors match Apple's Activity app: Move = red, Exercise = green, Stand = teal.
// Hidden automatically when no health data is present — caller checks entry.healthDataFetched.

import SwiftUI

struct ActivityRingsView: View {
    let activeCalories: Double
    let exerciseMinutes: Double
    let standHours: Double
    let workoutName: String?
    let workoutDuration: Int?
    let workoutCalories: Double?

    var style: any AppThemeStyle

    private let moveColor   = Color(red: 1.0,  green: 0.23, blue: 0.19)
    private let exerciseColor = Color(red: 0.20, green: 0.78, blue: 0.35)
    private let standColor  = Color(red: 0.0,  green: 0.78, blue: 0.75)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel
            HStack(alignment: .center, spacing: 20) {
                rings
                VStack(alignment: .leading, spacing: 12) {
                    inlineStats
                    if workoutName != nil {
                        workoutRow
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Section Label

    var sectionLabel: some View {
        Text("Activity")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .textCase(.uppercase)
            .padding(.bottom, 14)
    }

    // MARK: - Rings

    var rings: some View {
        ZStack {
            RingShape(radius: 38, lineWidth: 7, progress: 0.75)
                .stroke(moveColor.opacity(0.15), lineWidth: 7)
            RingShape(radius: 38, lineWidth: 7, progress: 0.75)
                .stroke(moveColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))

            RingShape(radius: 29, lineWidth: 7, progress: 0.65)
                .stroke(exerciseColor.opacity(0.15), lineWidth: 7)
            RingShape(radius: 29, lineWidth: 7, progress: 0.65)
                .stroke(exerciseColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))

            RingShape(radius: 20, lineWidth: 7, progress: 0.60)
                .stroke(standColor.opacity(0.15), lineWidth: 7)
            RingShape(radius: 20, lineWidth: 7, progress: 0.60)
                .stroke(standColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        .frame(width: 90, height: 90)
    }

    // MARK: - Stats

    var inlineStats: some View {
        HStack(alignment: .top, spacing: 16) {
            statColumn(color: moveColor, label: "Move",
                       value: "\(Int(activeCalories)) cal")
            statColumn(color: exerciseColor, label: "Exercise",
                       value: "\(Int(exerciseMinutes)) min")
            statColumn(color: standColor, label: "Stand",
                       value: "\(Int(standHours)) hrs")
        }
    }

    func statColumn(color: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Workout Row

    var workoutRow: some View {
        HStack(spacing: 10) {
            Image(systemName: workoutIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(exerciseColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(workoutName ?? "Workout")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text(workoutMeta)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    var workoutMeta: String {
        var parts: [String] = []
        if let duration = workoutDuration { parts.append("\(duration) min") }
        if let calories = workoutCalories, calories > 0 { parts.append("\(Int(calories)) cal") }
        return parts.joined(separator: " · ")
    }

    var workoutIcon: String {
        switch workoutName?.lowercased() {
        case "running": return "figure.run"
        case "cycling": return "figure.outdoor.cycle"
        case "walking": return "figure.walk"
        case "swimming": return "figure.pool.swim"
        case "hiking": return "figure.hiking"
        case "yoga": return "figure.yoga"
        case "strength training": return "dumbbell.fill"
        case "hiit": return "bolt.fill"
        case "rowing": return "figure.rowing"
        case "elliptical": return "figure.elliptical"
        case "pilates": return "figure.pilates"
        case "dance": return "figure.dance"
        default: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Ring Shape

struct RingShape: Shape {
    let radius: CGFloat
    let lineWidth: CGFloat
    let progress: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: -90 + 360 * Double(progress))
        var path = Path()
        path.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false)
        return path
    }
}
