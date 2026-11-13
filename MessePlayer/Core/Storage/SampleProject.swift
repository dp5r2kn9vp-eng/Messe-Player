import Foundation

/// Beispielprojekt zum Ausprobieren: eine Gruppe mit zwei Bildern, Logo, Texten und Animationen.
nonisolated enum SampleProject {
    static let fileName = "CueView Beispiel.klangshow"

    /// Legt das Beispiel unter `folder` an, falls es noch fehlt, und liefert seine Adresse.
    static func ensure(in folder: URL, bundle: Bundle = .main) throws -> URL {
        let url = folder.appending(path: fileName)
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }
        let (project, media) = try make(bundle: bundle)
        try ProjectPackage.write(project, media: media).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    static func make(bundle: Bundle) throws -> (Project, MediaStore) {
        var media = MediaStore()
        var project = Project()
        project.media = try ["beispiel-buehne", "beispiel-lounge"].map { name in
            guard let url = bundle.url(forResource: name, withExtension: "jpg") else { throw CocoaError(.fileNoSuchFile) }
            return try media.add(url)
        }
        let outputID = project.outputs.first?.id
        project.cues = project.media.enumerated().map { index, medium in
            var cue = Cue(number: String(index + 1), mediumID: medium.id, outputID: outputID)
            cue.stillDuration = 6
            cue.followAction = .followOnEnd
            return cue
        }
        project.cues[0].layers = [logoLayer(), welcomeText()]
        project.cues[1].layers = [nextShowText()]
        var group = CueGroup(name: String(localized: "Beispiel-Loop"), firstCueID: project.cues[0].id, lastCueID: project.cues[1].id)
        group.crossfade = 1
        project.groups = [group]
        return (project, media)
    }

    private static func logoLayer() -> Layer {
        var layer = Layer.logo()
        layer.animation = LayerAnimation(entrance: .slideDown, duration: 1)
        return layer
    }

    private static func welcomeText() -> Layer {
        var layer = Layer.text(String(localized: "Willkommen am KlangNIVEAU-Stand"))
        layer.position = RelativePoint(x: 0.5, y: 0.82)
        layer.animation = LayerAnimation(entrance: .fade, delay: 1, duration: 1)
        return layer
    }

    private static func nextShowText() -> Layer {
        var layer = Layer.text(String(localized: "Nächster Auftritt um 15 Uhr"))
        layer.position = RelativePoint(x: 0.5, y: 0.8)
        layer.animation = LayerAnimation(entrance: .typewriter, delay: 0.5, duration: 1.5, effect: .pulse, effectPeriod: 2)
        if case .text(var style) = layer.content {
            style.background = RGBAColor(red: 0.93, green: 0.11, blue: 0.15, alpha: 0.9)
            layer.content = .text(style)
        }
        return layer
    }
}
