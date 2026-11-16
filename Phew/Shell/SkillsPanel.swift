import SwiftUI

/// The menu's "Skills": the small functions Phew wrote for himself (phase NC), each with what it does and Delete.
@MainActor
final class SkillsModel: ObservableObject {
    @Published private(set) var skills: [Skill] = []
    let brain: any Brain

    init(brain: any Brain) { self.brain = brain }

    func refresh() async { skills = await brain.skills() }

    /// Gone at once: a skill is only code he can write again.
    func delete(_ name: String) async {
        await brain.deleteSkill(name)
        await refresh()
        shellLog("skills: one deleted, \(skills.count) kept")
    }

    static func madeText(_ date: Date) -> String {
        "Made " + date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct SkillsView: View {
    @ObservedObject var model: SkillsModel

    var body: some View {
        PanelList(isEmpty: model.skills.isEmpty, emptyLine: "No skills yet.",
                  help: "Small functions Phew wrote for himself during a research task. They only compute: text in, text out, in a closed box with no network, no files and no apps.") {
            ForEach(model.skills) { skill in
                Row(title: skill.name, detail: skill.about.isEmpty ? SkillsModel.madeText(skill.made) : "\(skill.about) \(SkillsModel.madeText(skill.made)).") {
                    Button("Delete") { Task { await model.delete(skill.name) } }.buttonStyle(QuietButton())
                }
            }
        }
        .task { await model.refresh() }
    }
}
