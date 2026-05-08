// virtual_iff.cpp  –  Proof-of-Concept for 2kDer core
// ---------------------------------------------------------------
//
// Placeholder implementation that just passes through the original
// file unchanged.  Once we integrate a ZIP library (minizip / zlib)
// and hook the file-open calls, this file will contain the actual
// decompress-patch-recompress logic.
//
// For now, this file exists so the project compiles and shows the
// intended API.  All the real work lives in the header comments and
// the Lua module design.

#include "virtual_iff.h"
#include <fstream>
#include <filesystem>

std::vector<uint8_t> VirtualIFF::PatchArchive(
    const std::wstring& original_iff_path,
    const std::vector<LooseOverride>& overrides)
{
    // For the PoC, just read the original file and return it as-is.
    // In production, this will:
    //   1. Open the ZIP archive
    //   2. For each override, locate the matching entry
    //   3. Replace its data with the loose file content
    //   4. Re-compress and return the patched archive
    std::ifstream file(original_iff_path, std::ios::binary | std::ios::ate);
    if (!file) return {};

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::vector<uint8_t> buffer(size);
    file.read(reinterpret_cast<char*>(buffer.data()), size);

    // TODO: actual patching once ZIP support is added

    return buffer;
}

std::vector<VirtualIFF::LooseOverride> VirtualIFF::FindLooseOverrides(
    const std::wstring& iff_name)
{
    // Placeholder – returns empty list.
    // Will scan liveff_textures/<iff_name>/ for loose files.
    return {};
}

bool VirtualIFF::DumpArchive(
    const std::wstring& iff_path,
    const std::wstring& output_dir)
{
    // Placeholder – always returns false.
    // Will decompress the archive and write all entries to disk.
    return false;
}
