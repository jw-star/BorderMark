import Foundation
import Testing
@testable import BorderMarkCore

@Suite("完整相机名")
struct CameraNameTests {
    @Test("品牌用规范写法且不与型号重复", arguments: [
        ("NIKON CORPORATION", "NIKON Z5_2", "Nikon Z5_2"),
        ("NIKON CORPORATION", "NIKON Z 8", "Nikon Z 8"),
        ("SONY", "ILCE-7M4", "SONY ILCE-7M4"),
        ("Canon", "Canon EOS R5", "Canon EOS R5"),
        ("FUJIFILM", "X100VI", "FUJIFILM X100VI"),
        ("Apple", "iPhone 15 Pro", "Apple iPhone 15 Pro"),
        ("LEICA CAMERA AG", "LEICA Q3", "Leica Q3"),
        ("Phase One", "IQ4 150MP", "Phase IQ4 150MP"),
        ("", "X100VI", "X100VI"),
        ("NIKON CORPORATION", "", "Nikon"),
        ("", "", ""),
    ])
    func cameraName(make: String, model: String, expected: String) {
        #expect(PlaceholderResolver.cameraName(make: make, model: model) == expected)
    }

    @Test("型号只是碰巧以品牌字母开头时不截断")
    func doesNotStripLookalikePrefix() {
        #expect(PlaceholderResolver.cameraName(make: "NIKON", model: "NIKONOS V") == "Nikon NIKONOS V")
    }

    @Test("{Camera} 占位符可用，并跟随手动填写的品牌和机型")
    func placeholderFollowsOverrides() {
        let metadata = PhotoMetadata(make: "NIKON CORPORATION", model: "NIKON Z5_2")
        #expect(PlaceholderResolver(metadata: metadata).resolve("{Camera}") == "Nikon Z5_2")

        let overridden = RenderOptions(fieldOverrides: ["Model": "Z f"])
        #expect(PlaceholderResolver(metadata: metadata, options: overridden).resolve("{Camera}") == "Nikon Z f")

        let replaced = RenderOptions(fieldOverrides: ["Camera": "我的相机"])
        #expect(PlaceholderResolver(metadata: metadata, options: replaced).resolve("{Camera}") == "我的相机")
    }

    @Test("没有任何相机信息时这一行不显示")
    func emptyWhenNoMetadata() {
        #expect(PlaceholderResolver(metadata: PhotoMetadata()).resolve("{Camera}") == nil)
    }
}

@Suite("逐行文字与 Logo 颜色")
struct LineAndLogoOptionTests {
    private func classic() throws -> Template {
        try #require(BuiltinTemplates.all.first { $0.id == "classic-white" })
    }

    private func lines(of template: Template, element: Int, item: Int) -> [TextLine] {
        guard case .group(let group) = template.elements[element],
              case .text(let lines, _, _) = group.items[item] else { return [] }
        return lines
    }

    @Test("经典模式：副标题是完整相机名，字体与下面的参数行完全一致")
    func classicSubtitleMatchesParams() throws {
        let right = lines(of: try classic(), element: 1, item: 2)

        #expect(right.map(\.text) == ["{Camera}", "{Params}"])
        #expect(right[0].size == right[1].size)
        #expect(right[0].weight == right[1].weight)
        #expect(right[0].color == right[1].color)
    }

    @Test("文字行按出现顺序编号，并带上位置信息")
    func slotsAreNumberedInOrder() throws {
        let slots = try classic().textLineSlots

        #expect(slots.map(\.id) == [0, 1, 2, 3])
        #expect(slots.map(\.text) == ["{Lens}", "{DateTime}", "{Camera}", "{Params}"])
        #expect(slots.map(\.h) == [.leading, .leading, .trailing, .trailing])
        #expect(slots.map(\.row) == [0, 1, 0, 1])
        #expect(slots.allSatisfy { $0.region == .bottom })
    }

    @Test("按行号改写文字，其他行不受影响")
    func overridesSingleLine() throws {
        let applied = try classic().applying(RenderOptions(lineOverrides: [2: "{Model}", 1: ""]))

        #expect(lines(of: applied, element: 0, item: 0).map(\.text) == ["{Lens}", ""])
        #expect(lines(of: applied, element: 1, item: 2).map(\.text) == ["{Model}", "{Params}"])
    }

    @Test("隐藏 Logo 后行号不变")
    func lineIndexStableWhenLogoHidden() throws {
        let options = RenderOptions(isLogoVisible: false, lineOverrides: [3: "改过"])
        let applied = try classic().applying(options)

        #expect(lines(of: applied, element: 1, item: 0).map(\.text) == ["{Camera}", "改过"])
    }

    @Test("每个内置模式的行号都与改写结果对应", arguments: BuiltinTemplates.all)
    func everySlotIsOverridable(template: Template) {
        let slots = template.textLineSlots
        let overrides = Dictionary(uniqueKeysWithValues: slots.map { ($0.id, "行\($0.id)") })

        let applied = template.applying(RenderOptions(lineOverrides: overrides))

        #expect(applied.textLineSlots.map(\.text) == slots.map { "行\($0.id)" })
    }

    @Test("Logo 颜色：自定义优先，其次文字颜色，最后模板颜色")
    func logoColorPrecedence() throws {
        func logoColor(_ options: RenderOptions) throws -> String? {
            guard case .group(let group) = try classic().applying(options).elements[1],
                  case .logo(_, let color) = group.items[0] else { return nil }
            return color
        }

        #expect(try logoColor(RenderOptions()) == "#111111")
        #expect(try logoColor(RenderOptions(textColor: "#00FF00")) == "#00FF00")
        #expect(try logoColor(RenderOptions(textColor: "#00FF00", logoColor: "#FF0000")) == "#FF0000")
    }

    @Test("内置模式的默认边框是原设计的 0.7 倍", arguments: [
        ("blur-card", 0.063, 0.133), ("classic-white", 0.0, 0.091), ("polaroid", 0.042, 0.182),
    ])
    func defaultBordersAreNarrowed(id: String, side: Double, bottom: Double) throws {
        let template = try #require(BuiltinTemplates.all.first { $0.id == id })
        #expect(template.border.left == side)
        #expect(template.border.right == side)
        #expect(template.border.bottom == bottom)
    }

    @Test("带 Logo 位置的模式能被识别出来")
    func hasLogoFlag() {
        let withLogo = Set(BuiltinTemplates.all.filter(\.hasLogo).map(\.id))
        #expect(withLogo == [
            "classic-white", "classic-black", "gallery-frame", "blur-card", "dominant-card", "gradient-poster",
        ])
    }

    @Test("默认的毛玻璃卡片带 Logo，且底栏两行都不加粗")
    func blurCardHasLogoAndRegularText() throws {
        let card = try #require(BuiltinTemplates.all.first { $0.id == "blur-card" })
        #expect(card.hasLogo)
        let weights = card.elements[0].items.flatMap { item -> [FontWeight] in
            if case .text(let lines, _, _) = item { return lines.map(\.weight) }
            return []
        }
        #expect(weights == [.regular, .regular])
    }

    @Test("毛玻璃卡片：第一行是 Logo 加相机名，第二行是参数")
    func blurCardRows() throws {
        let card = try #require(BuiltinTemplates.all.first { $0.id == "blur-card" })
        guard case .stack(let stack) = card.elements[0] else {
            Issue.record("毛玻璃卡片的底栏应为上下堆叠")
            return
        }

        #expect(stack.rows.count == 2)
        guard case .logo = stack.rows[0][0], case .text(let nameLines, _, _) = stack.rows[0][1],
              case .text(let paramLines, _, _) = stack.rows[1][0] else {
            Issue.record("第一行应为 Logo + 文字，第二行应为文字")
            return
        }
        #expect(nameLines.map(\.text) == ["{Model}"])
        #expect(paramLines.map(\.text) == ["{Params}"])
        #expect(card.textLineSlots.map(\.row) == [0, 1])
    }

    @Test("堆叠元素隐藏 Logo 后只剩文字，行号不变")
    func stackDropsLogoKeepsLineIndex() throws {
        let card = try #require(BuiltinTemplates.all.first { $0.id == "blur-card" })
        let applied = card.applying(RenderOptions(isLogoVisible: false, lineOverrides: [1: "改过"]))

        #expect(!applied.hasLogo)
        #expect(applied.textLineSlots.map(\.text) == ["{Model}", "改过"])
    }

    @Test("经典模式底栏四行都不加粗")
    func classicBottomBarIsRegular() throws {
        let template = try classic()
        let weights = lines(of: template, element: 0, item: 0) + lines(of: template, element: 1, item: 2)
        #expect(weights.map(\.weight) == [.regular, .regular, .regular, .regular])
    }

    @Test("统一粗细会覆盖每一行，默认不覆盖")
    func fontWeightOverride() throws {
        let bold = try classic().applying(RenderOptions(fontWeight: .bold))
        #expect(lines(of: bold, element: 0, item: 0).allSatisfy { $0.weight == .bold })
        #expect(lines(of: bold, element: 1, item: 2).allSatisfy { $0.weight == .bold })
    }

    @Test("自定义 Logo 颜色不改变文字颜色")
    func logoColorLeavesTextAlone() throws {
        let applied = try classic().applying(RenderOptions(logoColor: "#FF0000"))
        #expect(lines(of: applied, element: 1, item: 2).allSatisfy { $0.color == "#111111" })
    }
}
