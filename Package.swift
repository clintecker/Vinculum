// swift-tools-version: 6.2
import PackageDescription

// Vinculum — native LaTeX math parsing and typesetting for Apple platforms.
// VinculumLayout is platform-free (LaTeX → a TeX-style node tree, with
// document-scoped \newcommand macro expansion); VinculumRender lays each
// node out as geometry and draws it with CoreText/CoreGraphics behind a
// small MathTheme seam. No MathJax, no KaTeX, no WebView, no dependencies.
//
// The vinculum is the bar in a fraction, the line over a root — the stroke
// the typesetter draws to bind an expression together.
let package = Package(
    name: "Vinculum",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1), .tvOS(.v17)],
    products: [
        .library(name: "VinculumLayout", targets: ["VinculumLayout"]),
        .library(name: "VinculumRender", targets: ["VinculumRender"]),
    ],
    targets: [
        .target(name: "VinculumLayout", path: "Sources/VinculumLayout"),
        .target(name: "VinculumRender", dependencies: ["VinculumLayout"], path: "Sources/VinculumRender",
                resources: [.copy("Resources/latinmodern-math.otf"),
                            .copy("Resources/texgyretermes-math.otf"),
                            .copy("Resources/texgyrepagella-math.otf"),
                            .copy("Resources/stixtwo-math.otf"),
                            .copy("Resources/firamath.otf"),
                            .copy("Resources/LatinModernMath-LICENSE.txt"),
                            .copy("Resources/GUST-FONT-LICENSE.txt"),
                            .copy("Resources/README-TeX-Gyre-Termes-Math.txt"),
                            .copy("Resources/README-TeX-Gyre-Pagella-Math.txt"),
                            .copy("Resources/OFL-STIXTwo.txt"),
                            .copy("Resources/OFL-FiraMath.txt")]),
        .executableTarget(name: "VinculumDemo", dependencies: ["VinculumRender"],
                          path: "Sources/VinculumDemo"),
        .testTarget(name: "VinculumLayoutTests", dependencies: ["VinculumLayout"], path: "Tests/VinculumLayoutTests"),
        .testTarget(name: "VinculumRenderTests", dependencies: ["VinculumRender", "VinculumLayout"], path: "Tests/VinculumRenderTests"),
    ]
)
