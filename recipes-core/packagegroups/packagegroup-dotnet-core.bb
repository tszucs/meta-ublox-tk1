DESCRIPTION = "Provides runtime dependencies for .NET Core 2.0"

inherit packagegroup

PACKAGES = "packagegroup-dotnet-deps"

RDEPENDS_packagegroup-dotnet-deps = "\
    libunwind \
    icu \
    libcurl \
"
