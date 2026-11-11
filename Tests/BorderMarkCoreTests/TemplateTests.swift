import CoreGraphics
import Foundation
import Testing
@testable import BorderMarkCore

@Suite("颜色解析")
struct HexColorTests {
    @Test("支持 3/6/8 位写法")
    func parsesFormats() {
        #expect(HexColor.parse("#FFF") == HexColor.parse("#FFFFFF"))
        #expect(HexColor.parse("000000")?.red == 0)
        #expect(HexColor.parse("#FF000080")?.alpha == 128.0 / 255.0)
    }

    @Test("非法写法返回 nil", arguments: ["", "#12", "#GGGGGG", "red", "#1234567"])
    func rejectsInvalid(input: String) {
        #expect(HexColor.parse(input) == nil)
    }

    @Test("转回字符串")
    func formatsString() {
        #expect(HexColor.string(red: 1, green: 0, blue: 0) == "#FF0000")
        #expect(HexColor.string(red: 0, green: 0, blue: 0, alpha: 0.5) == "#00000080")
    }
}

@Suite("画布几何")
struct CanvasLayoutTests {
    private let layout = CanvasLayout(
        photoSize: CGSize(width: 3000, height: 2000),
        border: EdgeRatios(top: 0.05, left: 0.05, bottom: 0.2, right: 0.05)
    )

    @Test("边框按短边比例展开")
    func canvasGrowsByBorder() {
        #expect(layout.base == 2000)
        #expect(layout.canvasSize == CGSize(width: 3200, height: 2500))
        #expect(layout.photoRect == CGRect(x: 100, y: 100, width: 3000, height: 2000))
    }

    @Test("各区域矩形")
    func regionRects() {
        #expect(layout.rect(for: .bottom) == CGRect(x: 0, y: 2100, width: 3200, height: 400))
        #expect(layout.rect(for: .top) == CGRect(x: 0, y: 0, width: 3200, height: 100))
        #expect(layout.rect(for: .right) == CGRect(x: 3100, y: 0, width: 100, height: 2500))
        #expect(layout.rect(for: .photo) == layout.photoRect)
    }

    @Test("九宫格摆放与内缩")
    func placement() {
        let size = CGSize(width: 200, height: 100)
        let centered = layout.place(size: size, in: .bottom, h: .center, v: .center)
        #expect(centered == CGRect(x: 1500, y: 2250, width: 200, height: 100))

        let corner = layout.place(size: size, in: .photo, h: .trailing, v: .bottom, insetX: 0.01, insetY: 0.02)
        #expect(corner == CGRect(x: 2880, y: 1960, width: 200, height: 100))
    }

    @Test("竖图以宽为基准")
    func portraitUsesWidth() {
        let portrait = CanvasLayout(photoSize: CGSize(width: 1000, height: 1500), border: EdgeRatios(all: 0.1))
        #expect(portrait.canvasSize == CGSize(width: 1200, height: 1700))
    }
}

@Suite("模板")
struct TemplateTests {
    @Test("毛玻璃卡片排在第一个")
    func blurCardIsFirst() {
        #expect(BuiltinTemplates.all.first?.id == "blur-card")
    }

    @Test("内置模板 id 唯一且非空")
    func builtinIDsAreUnique() {
        let ids = BuiltinTemplates.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.count >= 12)
    }

    @Test("所有内置模板都能 JSON 往返")
    func builtinsRoundTrip() throws {
        for template in BuiltinTemplates.all {
            let data = try TemplateStore.encode(template)
            #expect(try TemplateStore.decode(data, fileName: "\(template.id).json") == template)
        }
    }

    @Test("内置模板只使用受支持的占位符")
    func builtinsUseKnownPlaceholders() throws {
        let known = Set(PlaceholderResolver.supportedKeys)
        for template in BuiltinTemplates.all {
            let json = String(decoding: try TemplateStore.encode(template), as: UTF8.self)
            for match in json.matches(of: /\{([A-Za-z0-9]+)\}/) {
                #expect(known.contains(String(match.1)), "\(template.id) 用了未知占位符 \(match.1)")
            }
        }
    }

    @Test("坏模板给出指明文件的错误", arguments: [
        "not json",
        ##"{"id":"","name":"x","summary":"","border":{"top":0,"left":0,"bottom":0,"right":0},"background":{"solid":{"color":"#FFF"}},"photo":{"cornerRadius":0},"elements":[]}"##,
        ##"{"id":"a","name":"x","summary":"","border":{"top":9,"left":0,"bottom":0,"right":0},"background":{"solid":{"color":"#FFF"}},"photo":{"cornerRadius":0},"elements":[]}"##,
        ##"{"id":"a","name":"x","summary":"","border":{"top":0,"left":0,"bottom":0,"right":0},"background":{"solid":{"color":"nope"}},"photo":{"cornerRadius":0},"elements":[]}"##,
        ##"{"id":"a","name":"x","summary":"","border":{"top":0,"left":0,"bottom":0,"right":0},"background":{"solid":{"color":"#FFF"}},"photo":{"cornerRadius":0},"elements":[{"circle":{}}]}"##,
    ])
    func rejectsInvalidTemplates(json: String) {
        #expect {
            try TemplateStore.decode(Data(json.utf8), fileName: "bad.json")
        } throws: { error in
            guard case BorderMarkError.invalidTemplate(let file, _) = error else { return false }
            return file == "bad.json"
        }
    }

    @Test("用户模板覆盖同 id 内置模板，新 id 追加在后")
    func mergesCustomTemplates() {
        let builtin = [Template(id: "a", name: "A"), Template(id: "b", name: "B")]
        let custom = [Template(id: "b", name: "B2"), Template(id: "c", name: "C")]
        let merged = TemplateStore.merged(builtin: builtin, custom: custom)
        #expect(merged.map(\.name) == ["A", "B2", "C"])
    }

    @Test("从目录加载：好文件生效，坏文件进问题列表")
    func loadsFromDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let custom = Template(id: "my-style", name: "我的样式", border: EdgeRatios(all: 0.1))
        try TemplateStore.encode(custom).write(to: directory.appendingPathComponent("my.json"))
        try Data("oops".utf8).write(to: directory.appendingPathComponent("broken.json"))

        let result = TemplateStore.load(from: directory)
        #expect(result.templates.last == custom)
        #expect(result.templates.count == BuiltinTemplates.all.count + 1)
        #expect(result.problems.count == 1)
        #expect(result.problems.first?.contains("broken.json") == true)
    }

    @Test("导出内置模板不覆盖已有文件")
    func exportBuiltinsIsIdempotent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try TemplateStore.exportBuiltins(to: directory) == BuiltinTemplates.all.count)
        #expect(try TemplateStore.exportBuiltins(to: directory) == 0)
        #expect(TemplateStore.load(from: directory).templates == BuiltinTemplates.all)
    }
}

@Suite("用户调整")
struct RenderOptionsTests {
    private let classic = BuiltinTemplates.all.first { $0.id == "classic-white" } ?? BuiltinTemplates.all[0]

    @Test("默认选项不改变模板")
    func defaultIsIdentity() {
        for template in BuiltinTemplates.all {
            #expect(template.applying(RenderOptions()) == template)
        }
    }

    @Test("边框和文字分别缩放")
    func scalesBorderAndText() {
        let applied = classic.applying(RenderOptions(borderScale: 2, textScale: 0.5))
        #expect(applied.border.bottom == classic.border.bottom * 2)
        guard case .group(let group) = applied.elements[0], case .text(let lines, _, _) = group.items[0] else {
            Issue.record("经典模板的第一个元素应为文字组")
            return
        }
        #expect(lines[0].size == 0.016)
    }

    @Test("隐藏 Logo 时连同分隔线一起去掉")
    func hidingLogoDropsDivider() {
        let applied = classic.applying(RenderOptions(isLogoVisible: false))
        guard case .group(let group) = applied.elements[1] else {
            Issue.record("经典模板的第二个元素应为组")
            return
        }
        #expect(group.items.count == 1)
    }

    @Test("覆盖背景、文字颜色、圆角、阴影、字体")
    func overridesStyle() {
        let options = RenderOptions(
            background: .solid(color: "#123456"), textColor: "#ABCDEF",
            cornerRadius: 0.05, isShadowEnabled: true, fontName: "Menlo"
        )
        let applied = classic.applying(options)
        #expect(applied.background == .solid(color: "#123456"))
        #expect(applied.photo.cornerRadius == 0.05)
        #expect(applied.photo.shadow == .standard)
        #expect(applied.fontName == "Menlo")
        guard case .group(let group) = applied.elements[0], case .text(let lines, _, _) = group.items[0] else {
            Issue.record("经典模板的第一个元素应为文字组")
            return
        }
        #expect(lines.allSatisfy { $0.color == "#ABCDEF" })
    }

    @Test("关闭阴影会移除模板自带的阴影")
    func disablingShadowRemovesIt() throws {
        let card = try #require(BuiltinTemplates.all.first { $0.id == "blur-card" })
        #expect(card.applying(RenderOptions(isShadowEnabled: false)).photo.shadow == nil)
    }

    @Test("平铺水印换色时保留透明度")
    func tileKeepsAlpha() throws {
        let tiled = try #require(BuiltinTemplates.all.first { $0.id == "tiled" })
        let applied = tiled.applying(RenderOptions(textColor: "#FF0000"))
        guard case .tile(let tile) = applied.elements[0] else {
            Issue.record("平铺模板应包含 tile 元素")
            return
        }
        #expect(tile.color == "#FF000040")
    }
}
