import SwiftUI

struct VetPilotReviewDraft {
    var id = UUID()
    var rating = 0
    var role = "Veterinary Technician"
    var otherRole = ""
    var features = Set<String>()
    var otherFeature = ""
    var accuracy = "I am not qualified to evaluate clinical accuracy"
    var correctionFeature = "", correctionItem = "", problem = "", suggestion = "", source = ""
    var ease = "Okay", workplace = "Maybe", recommend = "Maybe"
    var categories: Set<String> = ["General feedback"]
    var comments = ""
    var licensedVet = false
    var reviewAreas = Set<String>()
    var otherReview = "", name = "", credentials = "", organization = ""
    var testimonialPermission = false
    var clinicalPriority: Bool { accuracy == "Something may be incorrect" || categories.contains("Found a possible error") }
    var validationError: String? {
        if !(1...5).contains(rating) { return "Choose a rating from 1 to 5." }
        if features.isEmpty { return "Select at least one feature you used." }
        if categories.isEmpty { return "Select a feedback type." }
        if role == "Other" && otherRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Describe your role." }
        if features.contains("Other") && otherFeature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Name the other feature." }
        if clinicalPriority && [correctionFeature, correctionItem, problem].contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return "Identify the feature, item, and possible error." }
        if licensedVet && reviewAreas.isEmpty { return "Select the clinical areas you reviewed." }
        if reviewAreas.contains("Other") && otherReview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Describe the other review area." }
        if [otherRole, otherFeature, correctionFeature, correctionItem, otherReview, name, credentials, organization].contains(where: { $0.utf16.count > 200 }) { return "Short fields must be 200 characters or fewer." }
        if [problem, suggestion, source, comments].contains(where: { $0.utf16.count > 5000 }) { return "Comments and correction details must be 5,000 characters or fewer." }
        return nil
    }
    func record(owner: UUID) -> [String: Any] {
        let payload: [String: Any] = [
            "id": id.uuidString.lowercased(), "owner": owner.uuidString.lowercased(), "rating": rating,
            "role": role, "otherRole": otherRole, "features": features.sorted(), "otherFeature": otherFeature,
            "accuracy": accuracy, "correction": ["feature": correctionFeature, "item": correctionItem, "problem": problem, "suggestion": suggestion, "source": source],
            "ease": ease, "workplace": workplace, "recommend": recommend,
            "categories": categories.sorted(), "categoryComments": [String: String](), "comments": comments,
            "licensedVet": licensedVet, "reviewAreas": reviewAreas.sorted(), "otherReview": otherReview,
            "reviewer": ["name": name, "credentials": credentials, "organization": organization],
            "testimonialPermission": testimonialPermission, "context": "VetPilot iOS " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        ]
        return ["id": id.uuidString.lowercased(), "user_id": owner.uuidString.lowercased(), "rating": rating, "clinical_priority": clinicalPriority, "payload": payload]
    }
}

struct RatingsReviewsView: View {
    @ObservedObject var account: VetPilotAccount
    var onAccount: (() -> Void)? = nil
    @State private var draft = VetPilotReviewDraft()
    @State private var busy = false
    @State private var done = false
    @State private var error: String?
    @State private var prior: [ReviewSummary] = []
    private let roles = ["Veterinarian", "Veterinary Technician", "Veterinary Assistant", "Veterinary Student", "Practice Manager", "Other"]
    private let features = ["Medications", "Nutrition", "Labwork", "Administration", "My Clinic", "Cytology", "Breeds", "Other"]
    private let categories = ["General feedback", "Found a possible error", "Feature request", "Improvement suggestion", "Technical problem"]
    private let areas = ["Medication dosing information", "Medication calculations", "Nutrition calculations", "Labwork information", "Administration calculations", "Other"]
    var body: some View {
        Form {
            Section {
                Text("Help improve VetPilot. Feedback is private and available in the owner’s review inbox. Do not include patient or client identifying information.")
                if account.userID == nil {
                    Text("Sign in to submit a rating or review.")
                    if let onAccount { Button("Sign in") { onAccount() } }
                }
            }
            if account.userID != nil {
                if done {
                    Section { Text("Thank you—your feedback was submitted.").accessibilityIdentifier("reviews.success"); Button("Write another review") { draft = VetPilotReviewDraft(); done = false } }
                } else {
                    Group {
                        Section("Your experience") {
                            Picker("Rating", selection: $draft.rating) { Text("Choose rating").tag(0); ForEach(1...5, id: \.self) { Text("\($0) / 5").tag($0) } }
                            Picker("Role", selection: $draft.role) { ForEach(roles, id: \.self) { Text($0).tag($0) } }
                            if draft.role == "Other" { TextField("Your role", text: $draft.otherRole) }
                        }
                        choices("Features used", options: features, selected: $draft.features)
                        if draft.features.contains("Other") { TextField("Other feature", text: $draft.otherFeature) }
                        Section("Clinical accuracy") {
                            Picker("Accuracy", selection: $draft.accuracy) {
                                ForEach(["Accurate based on my review", "Something may be incorrect", "I am not qualified to evaluate clinical accuracy"], id: \.self) { Text($0).tag($0) }
                            }
                        }
                        choices("Feedback type", options: categories, selected: $draft.categories)
                        if draft.clinicalPriority {
                            Section("Possible error") {
                                TextField("Feature", text: $draft.correctionFeature)
                                TextField("Medication, calculation or item", text: $draft.correctionItem)
                                TextField("What may be incorrect?", text: $draft.problem, axis: .vertical)
                                TextField("Suggested correction (optional)", text: $draft.suggestion, axis: .vertical)
                                TextField("Supporting source (optional)", text: $draft.source, axis: .vertical)
                                Text("Reports are reviewed against clinical sources. Submitting a report does not change clinical information.").font(.caption)
                            }
                        }
                        Section("Usability") {
                            Picker("Ease of use", selection: $draft.ease) { ForEach(["Easy", "Okay", "Difficult"], id: \.self) { Text($0).tag($0) } }
                            Picker("Would use at work", selection: $draft.workplace) { ForEach(["Yes", "Maybe", "No"], id: \.self) { Text($0).tag($0) } }
                            Picker("Would recommend", selection: $draft.recommend) { ForEach(["Yes", "Maybe", "No"], id: \.self) { Text($0).tag($0) } }
                            TextField("Experience, requests or suggestions (optional)", text: $draft.comments, axis: .vertical).lineLimit(4...10)
                        }
                        Section("Professional review (optional)") {
                            Toggle("I am a licensed veterinarian and reviewed clinical information", isOn: $draft.licensedVet)
                            Text("Professional credentials are self-reported, not independently verified or formal clinical approval.").font(.caption)
                            TextField("Name (optional)", text: $draft.name)
                            TextField("Credentials (optional)", text: $draft.credentials)
                            TextField("Clinic / organization (optional)", text: $draft.organization)
                        }
                        choices("Areas reviewed (optional)", options: areas, selected: $draft.reviewAreas)
                        if draft.reviewAreas.contains("Other") { TextField("Other review area", text: $draft.otherReview) }
                        Section("Testimonial permission (optional)") {
                            Toggle("VetPilot may use my comments as a testimonial", isOn: $draft.testimonialPermission)
                            Text("Unchecked feedback stays internal. Permission does not publish anything automatically. Your account email is never displayed publicly.").font(.caption)
                        }
                        Section {
                            if let error { Text(error).foregroundStyle(.red) }
                            Button(busy ? "Submitting…" : "Submit Feedback") { Task { await submit() } }.accessibilityIdentifier("reviews.submit")
                        }
                    }.disabled(busy)
                }
                Section("Recent feedback") {
                    Button("Refresh feedback") { Task { await load() } }
                    ForEach(prior) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(item.rating) / 5 · \(item.status)").font(.headline)
                            Text(item.payload.comments)
                        }
                    }
                    if prior.isEmpty { Text("No submissions loaded.").foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle("Ratings & Reviews").task(id: account.userID) { prior = []; await load() }
    }
    private func choices(_ title: String, options: [String], selected: Binding<Set<String>>) -> some View {
        Section(title) {
            ForEach(options, id: \.self) { option in
                Toggle(option, isOn: Binding(get: { selected.wrappedValue.contains(option) }, set: { if $0 { selected.wrappedValue.insert(option) } else { selected.wrappedValue.remove(option) } }))
            }
        }
    }
    private func submit() async {
        guard !busy, let owner = account.userID else { return }
        if let message = draft.validationError { error = message; return }
        busy = true; defer { busy = false }; error = nil
        let submitted = draft
        do {
            // Keep the submission UUID on retry to prevent duplicate notifications.
            let path = "rest/v1/vetpilot_feedback?id=eq.\(submitted.id.uuidString.lowercased())&user_id=eq.\(owner.uuidString.lowercased())&select=id"
            let previous = try await account.request(path: path)
            let existing = try JSONSerialization.jsonObject(with: previous) as? [[String: Any]] ?? []
            guard account.userID == owner else { throw ScribeError.invalid("Your account changed. Reopen Reviews.") }
            if existing.isEmpty { _ = try await account.request(path: "rest/v1/vetpilot_feedback", method: "POST", body: submitted.record(owner: owner)) }
            done = true; await load()
        } catch { self.error = "Feedback could not be saved. Your entries are preserved; please retry. " + error.localizedDescription }
    }
    private func load() async {
        guard let owner = account.userID else { return }
        do {
            let data = try await account.request(path: "rest/v1/vetpilot_feedback?select=id,rating,status,payload&order=created_at.desc&limit=50")
            let rows = try JSONDecoder().decode([ReviewSummary].self, from: data)
            if account.userID == owner { prior = rows }
        } catch { self.error = error.localizedDescription }
    }
    private struct ReviewSummary: Decodable, Identifiable {
        let id: UUID
        let rating: Int
        let status: String
        let payload: Payload
        struct Payload: Decodable { let comments: String }
    }
}
