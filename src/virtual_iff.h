// virtual_iff.h  –  Proof-of-Concept for 2kDer core
// ---------------------------------------------------------------
//
// This header declares the VirtualIFF system that powers the Live
// Texture Injection feature.  It is a skeleton that will be filled
// once the core DLL is being built.
//
// The idea is simple: many .iff files in NBA 2K14 are standard ZIP
// archives.  We decompress them, swap out individual internal files
// with loose versions from liveff_textures/, and re-compress the
// whole thing in memory.  The game never sees the patch – it just
// receives a valid .iff with the modded content inside.
//
// This system was inspired by the way Chinese tools like RED MC
// already manipulate .iff files, and by the PES Sider's LiveCPK
// which does the same for .cpk archives.

#pragma once

#include <vector>
#include <string>
#include <cstdint>

namespace VirtualIFF {

    // One loose-file override.  "internal_path" is the path inside
    // the .iff archive (e.g., "score_texture.dds").  "disk_path" is
    // the absolute path to the replacement file on the user's drive.
    struct LooseOverride {
        std::string internal_path;
        std::string disk_path;
    };

    // Takes the original .iff file (or the LiveFF-redirected one)
    // and a list of loose files, then returns the complete patched
    // .iff as a vector of bytes ready to be served to the game.
    std::vector<uint8_t> PatchArchive(
        const std::wstring& original_iff_path,
        const std::vector<LooseOverride>& overrides
    );

    // Utility: list all loose overrides currently available for a
    // given .iff file.  This scans the liveff_textures/<iffname>/
    // directory and returns every file found inside.
    std::vector<LooseOverride> FindLooseOverrides(
        const std::wstring& iff_name
    );

    // Utility: dump all files from an .iff archive to a folder.
    // This is the extraction part that gives modders the original
    // textures to edit.
    bool DumpArchive(
        const std::wstring& iff_path,
        const std::wstring& output_dir
    );
}
