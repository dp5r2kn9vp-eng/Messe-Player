import Foundation
import Testing
@testable import MessePlayer

struct LayerAnimationTests {
    @Test func staticLayerIsAlwaysFullyVisible() {
        let animation = LayerAnimation()
        #expect(animation.isStatic)
        #expect(animation.frame(at: 0) == LayerAnimation.Frame())
        #expect(animation.frame(at: 100) == LayerAnimation.Frame())
    }

    @Test func delayKeepsLayerHiddenThenFadesIn() {
        let animation = LayerAnimation(entrance: .fade, delay: 1, duration: 1)
        #expect(animation.frame(at: 0.5).opacity == 0)
        let halfway = animation.frame(at: 1.5).opacity
        #expect(halfway > 0.5 && halfway < 1)
        #expect(animation.frame(at: 2).opacity == 1)
    }

    @Test func delayWithoutEntranceAppearsAtOnce() {
        let animation = LayerAnimation(delay: 2)
        #expect(animation.frame(at: 1.9).opacity == 0)
        #expect(animation.frame(at: 2).opacity == 1)
    }

    @Test func slideEndsAtItsPosition() {
        let animation = LayerAnimation(entrance: .slideUp, duration: 1)
        #expect(animation.frame(at: 0).offsetY > 0)
        #expect(animation.frame(at: 1).offsetY == 0)
        #expect(LayerAnimation(entrance: .slideLeft, duration: 1).frame(at: 0).offsetX > 0)
    }

    @Test func typewriterRevealsTextLinearly() {
        let animation = LayerAnimation(entrance: .typewriter, duration: 2)
        #expect(animation.frame(at: 1).reveal == 0.5)
        #expect(animation.frame(at: 1).opacity == 1)
    }

    @Test func blinkVariesOpacityAfterEntrance() {
        let animation = LayerAnimation(effect: .blink, effectPeriod: 1)
        #expect(animation.frame(at: 0).opacity == 1)
        #expect(animation.frame(at: 0.5).opacity < 0.2)
    }

    @Test func pulseScalesAroundOne() {
        let animation = LayerAnimation(effect: .pulse, effectPeriod: 1)
        #expect(animation.frame(at: 0.25).scale > 1)
        #expect(animation.frame(at: 0.75).scale < 1)
    }

    @Test func visibleForFadesOutAfterwards() {
        let animation = LayerAnimation(delay: 1, visibleFor: 3)
        #expect(animation.frame(at: 3.9).opacity == 1)
        #expect(animation.frame(at: 5).opacity == 0)
    }

    @Test func olderLayersWithoutAnimationStillOpen() throws {
        let json = Data(#"{"id": "\#(UUID())", "content": {"logo": {}}, "position": {"x": 0.5, "y": 0.2}, "width": 0.3}"#.utf8)
        let layer = try JSONDecoder().decode(Layer.self, from: json)
        #expect(layer.animation.isStatic)
        #expect(layer.width == 0.3)
    }

    @Test func settlesWhenNothingMovesAnymore() {
        #expect(LayerAnimation(entrance: .fade, delay: 1, duration: 2).settlesAfter == 3)
        #expect(LayerAnimation(delay: 1, visibleFor: 4).settlesAfter == 5.5)
        #expect(LayerAnimation(effect: .blink).settlesAfter == nil)
        #expect(LayerAnimation.settlesAfter([LayerAnimation(entrance: .zoom, duration: 1), LayerAnimation(delay: 2)]) == 2)
        #expect(LayerAnimation.settlesAfter([LayerAnimation(), LayerAnimation(effect: .pulse)]) == nil)
    }
}
