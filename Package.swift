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
//
// On Apple platforms VinculumRender draws with CoreText/CoreGraphics and never
// links Silica. On Linux it draws with Silica (Cairo/FontConfig) — a Linux-only
// rendering backend. Silica and its Cairo backend track `master` (Silica itself
// depends on Cairo by branch, so a stable version requirement can't be mixed
// in). Pulling Silica into the graph is why the toolchain floor is Swift 6.2:
// SwiftPM parses every manifest in the graph regardless of platform.
let package = Package(
    name: "Vinculum",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1), .tvOS(.v17)],
    products: [
        .library(name: "VinculumLayout", targets: ["VinculumLayout"]),
        .library(name: "VinculumRender", targets: ["VinculumRender"]),
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/Silica.git", branch: "master"),
        .package(url: "https://github.com/PureSwift/Cairo.git", branch: "master"),
    ],
    targets: [
        .target(name: "VinculumLayout", path: "Sources/VinculumLayout"),
        // Raw FreeType C shim — the Linux backend loads the bundled MATH .otf
        // fonts from bytes and extracts glyph outlines directly (Silica's
        // font-by-name path can't resolve non-default families). Built only
        // when depended on (Linux); Apple never references it.
        .systemLibrary(name: "CFreetypeShim", path: "Sources/CFreetypeShim",
                       pkgConfig: "freetype2",
                       providers: [.apt(["libfreetype6-dev"]), .brew(["freetype"])]),
        .target(name: "VinculumRender", dependencies: [
                    "VinculumLayout",
                    .product(name: "SilicaCairo", package: "Silica", condition: .when(platforms: [.linux])),
                    .product(name: "Cairo", package: "Cairo", condition: .when(platforms: [.linux])),
                    .target(name: "CFreetypeShim", condition: .when(platforms: [.linux])),
                ], path: "Sources/VinculumRender",
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
        .executableTarget(name: "VinculumLinuxSmoke", dependencies: ["VinculumRender"],
                          path: "Sources/VinculumLinuxSmoke"),
        .testTarget(name: "VinculumLayoutTests", dependencies: ["VinculumLayout"], path: "Tests/VinculumLayoutTests"),
        .testTarget(name: "VinculumRenderTests", dependencies: ["VinculumRender", "VinculumLayout"], path: "Tests/VinculumRenderTests"),
    ]
)
