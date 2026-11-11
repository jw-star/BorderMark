# 边框水印大师（BorderMark）

给照片加边框和拍摄参数水印的 macOS 应用。SwiftUI + 系统框架，无第三方依赖。

## 运行

只需要 Command Line Tools（或完整 Xcode），macOS 14 以上。

```bash
swift run BorderMark          # 直接运行
./scripts/bundle.sh           # 打包成 build/边框水印大师.app
./scripts/test.sh             # 跑测试
./scripts/make-app-icon.sh    # 重新生成 App 图标（Packaging/AppIcon.icns）
```

## 命令行

```bash
swift run bordermark-cli list
swift run bordermark-cli render 照片.jpg --template blur-card --out 输出目录
swift run bordermark-cli render *.jpg --all --author "署名" --format heic
swift run bordermark-cli export-templates     # 把内置模式写成 JSON
```

## 结构

```
Sources/BorderMarkCore   核心库：EXIF 读取、模板模型、渲染器、导入导出（纯逻辑，有测试）
Sources/BorderMarkApp    SwiftUI 界面
Sources/BorderMarkCLI    命令行工具
```

## 界面里能调的

- **调整**：边框宽度、文字大小、背景、文字颜色、圆角、阴影、字体、文字粗细、Logo 及其颜色。标题旁的“重置默认”一键恢复。
- **文字行**：当前模式的每一行文字都能直接改，或从预设（完整相机名、机型、镜头、参数、时间……）里选；每个模式各记各的。
- **文字内容**：署名、自定义文字，以及没有 EXIF 时手动填写的拍摄信息。
- **导出**：面板底部的“导出当前”和“批量导出”按钮，默认质量 100。导出时弹窗显示进度，可取消；结束后显示成功、失败数量，并可直接在访达中打开。默认模式是毛玻璃卡片。
- **Logo 位置**：经典白底/黑底、画廊白框、毛玻璃卡片、主色卡片、渐变海报带 Logo；其余模式没有 Logo 位置，界面会提示。

## 自定义水印模式

每个模式是一份 JSON，放进 `~/Library/Application Support/BorderMark/Templates/`，
在应用里点“重新加载”即可。id 与内置模式相同时会覆盖内置模式。
点“写出示例”可以得到全部内置模式的 JSON，照着改最快。

所有长度都是**相对照片短边的比例**（0.05 = 短边的 5%），所以预览和原图导出版式一致。

```json
{
  "id": "my-style",
  "name": "我的样式",
  "summary": "鼠标悬停时显示的说明",
  "border": { "top": 0.04, "left": 0.04, "bottom": 0.16, "right": 0.04 },
  "background": { "solid": { "color": "#FFFFFF" } },
  "photo": { "cornerRadius": 0.01, "shadow": { "radius": 0.03, "offsetY": 0.012, "opacity": 0.35 } },
  "fontName": "Georgia",
  "elements": [
    {
      "group": {
        "region": "bottom", "h": "center", "v": "center",
        "insetX": 0, "insetY": 0, "spacing": 0.02,
        "items": [
          { "logo": { "height": 0.04, "color": "#111111" } },
          { "divider": { "height": 0.05, "width": 0.002, "color": "#CCCCCC" } },
          { "text": {
              "align": "leading", "lineSpacing": 0.008,
              "lines": [
                { "text": "{Model}", "size": 0.03, "weight": "bold", "color": "#111111" },
                { "text": "{Params}", "size": 0.02, "weight": "regular", "color": "#888888" }
              ]
          } }
        ]
      }
    }
  ]
}
```

| 字段 | 可选值 |
|---|---|
| `background` | `solid{color}`、`gradient{from,to}`、`blur{radius,dim}`、`dominant{dim}` |
| `region` | `canvas`、`photo`、`top`、`bottom`、`left`、`right`（后四个是对应的边框带） |
| `h` / `v` | `leading` `center` `trailing` / `top` `center` `bottom` |
| `weight` | `light` `regular` `medium` `semibold` `bold` |
| 元素 | `group`（横排的文字、Logo、分隔线）、`stack`（多行上下堆叠，`rows` 里每一行是一组横排项目，另有 `rowSpacing`）或 `tile`（斜向平铺文字：`text,size,weight,color,angle,spacingX,spacingY,region`） |
| 颜色 | `#RGB`、`#RRGGBB`、`#RRGGBBAA` |

占位符：`{Make}` `{Model}` `{Camera}`（完整相机名，如 Nikon Z5_2）`{Lens}` `{FocalLength}` `{FocalLength35}` `{FNumber}` `{Shutter}` `{ISO}`
`{Params}`（焦距+光圈+快门+ISO）`{Date}` `{Time}` `{DateTime}` `{GPS}` `{Author}` `{Copyright}` `{Custom}`。
某一行的占位符全部为空时，这一行自动不画。

## 品牌 Logo

应用自带 20 个品牌的 Logo 图片（`Sources/BorderMarkCore/Resources/Logos`），打包时放进 `.app`。
界面“调整”里可以选：

- **自动匹配相机品牌**（默认）：按每张照片 EXIF 的厂商字段找同名 Logo，批量导出时不同相机各用各的。
- **仅品牌名文字**、**指定某个品牌**、**自选一张图片**。
- **Logo 颜色**：跟随文字（默认）、自定义颜色，或保留图片原色（彩色 Logo 用这个）。前两项只对透明底的 Logo 生效。

图片来源：

- Apple、DJI、FUJIFILM、Google、HUAWEI、Leica、Nikon、OPPO、Panasonic、SAMSUNG、SONY、vivo、Xiaomi：
  取自 [Simple Icons](https://simpleicons.org) 16.37.0（文件为 CC0-1.0），用 `scripts/svg-to-logo.swift` 转成透明底 PNG。
- Canon、HASSELBLAD、OLYMPUS、OM SYSTEM、PENTAX、RICOH、SIGMA：Simple Icons 未收录，
  暂用 `scripts/make-wordmark-logos.swift` 生成的品牌名字标。

各品牌 Logo 是其所有者的商标，CC0 只覆盖图标文件本身。自用没有问题；公开分发或上架前请自行确认商标使用是否合规。

要替换或补充：把以品牌命名的透明底 PNG（如 `Canon.png`）放进
`~/Library/Application Support/BorderMark/Logos/`（界面里点“Logo 文件夹”），同名会替换自带的；
或者直接替换源码目录里的文件后重新打包。文件名需是 EXIF 厂商字段的开头部分，不区分大小写。
