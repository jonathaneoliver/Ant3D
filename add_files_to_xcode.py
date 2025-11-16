#!/usr/bin/env python3
"""
Script to add new source files to Xcode project
"""

import os
import sys
import uuid


def generate_uuid():
    """Generate a 24-character hex UUID (Xcode style)"""
    return uuid.uuid4().hex[:24].upper()


def add_files_to_xcode(project_path, files_to_add, group_name):
    """
    Add files to Xcode project.pbxproj

    Args:
        project_path: Path to .xcodeproj/project.pbxproj
        files_to_add: List of file paths relative to project root
        group_name: Name of the group/folder in Xcode (e.g., "Input")
    """

    if not os.path.exists(project_path):
        print(f"❌ Project file not found: {project_path}")
        return False

    print(f"📝 Reading project file: {project_path}")
    with open(project_path, "r") as f:
        content = f.read()

    # Generate UUIDs for new entries
    group_id = generate_uuid()
    file_refs = {}
    build_files = {}

    for filepath in files_to_add:
        file_refs[filepath] = generate_uuid()
        build_files[filepath] = generate_uuid()

    print(f"\n🆔 Generated UUIDs:")
    print(f"   Group: {group_id}")
    for filepath in files_to_add:
        print(
            f"   {os.path.basename(filepath)}: {file_refs[filepath]} (ref), {build_files[filepath]} (build)"
        )

    # Find the main group section (where folder structure is defined)
    main_group_marker = "/* AntAttack3D */ = {"
    main_group_idx = content.find(main_group_marker)

    if main_group_idx == -1:
        print("❌ Could not find main group section")
        return False

    # Find the children array in the main group
    children_start = content.find("children = (", main_group_idx)
    children_end = content.find(");", children_start)

    # Add new group reference to main group's children
    new_group_ref = f"\t\t\t\t{group_id} /* {group_name} */,\n"
    insert_pos = children_end
    content = content[:insert_pos] + new_group_ref + content[insert_pos:]

    print(f"\n✅ Added {group_name} group reference to main group")

    # Create PBXGroup section for the new folder
    pbx_group_section = f"""/* Begin PBXGroup section */"""
    pbx_group_idx = content.find(pbx_group_section)

    if pbx_group_idx == -1:
        print("❌ Could not find PBXGroup section")
        return False

    # Create group entry
    file_refs_str = ""
    for filepath in files_to_add:
        filename = os.path.basename(filepath)
        file_refs_str += f"\t\t\t\t{file_refs[filepath]} /* {filename} */,\n"

    new_group = f"""
\t\t{group_id} /* {group_name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{file_refs_str}\t\t\t);
\t\t\tpath = {group_name};
\t\t\tsourceTree = "<group>";
\t\t}};"""

    # Insert after PBXGroup section marker
    insert_after = content.find("\n", pbx_group_idx) + 1
    content = content[:insert_after] + new_group + content[insert_after:]

    print(f"✅ Created PBXGroup for {group_name}")

    # Add PBXFileReference entries for each file
    file_ref_section = "/* Begin PBXFileReference section */"
    file_ref_idx = content.find(file_ref_section)

    if file_ref_idx == -1:
        print("❌ Could not find PBXFileReference section")
        return False

    file_refs_entries = ""
    for filepath in files_to_add:
        filename = os.path.basename(filepath)
        file_refs_entries += f"""\t\t{file_refs[filepath]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};
"""

    insert_after = content.find("\n", file_ref_idx) + 1
    content = content[:insert_after] + file_refs_entries + content[insert_after:]

    print(f"✅ Added PBXFileReference entries")

    # Add PBXBuildFile entries (to link files to compilation)
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_idx = content.find(build_file_section)

    if build_file_idx == -1:
        print("❌ Could not find PBXBuildFile section")
        return False

    build_files_entries = ""
    for filepath in files_to_add:
        filename = os.path.basename(filepath)
        build_files_entries += f"""\t\t{build_files[filepath]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filepath]} /* {filename} */; }};
"""

    insert_after = content.find("\n", build_file_idx) + 1
    content = content[:insert_after] + build_files_entries + content[insert_after:]

    print(f"✅ Added PBXBuildFile entries")

    # Add files to Sources build phase
    sources_phase_marker = "/* Sources */ = {"
    sources_phase_idx = content.find(sources_phase_marker)

    if sources_phase_idx == -1:
        print("❌ Could not find Sources build phase")
        return False

    # Find files array in sources phase
    files_start = content.find("files = (", sources_phase_idx)
    files_end = content.find(");", files_start)

    sources_entries = ""
    for filepath in files_to_add:
        filename = os.path.basename(filepath)
        sources_entries += (
            f"\t\t\t\t{build_files[filepath]} /* {filename} in Sources */,\n"
        )

    content = content[:files_end] + sources_entries + content[files_end:]

    print(f"✅ Added files to Sources build phase")

    # Write updated project file
    with open(project_path, "w") as f:
        f.write(content)

    print(f"\n✅ Successfully added {len(files_to_add)} files to Xcode project!")
    return True


if __name__ == "__main__":
    project_path = "/Users/jonathanoliver/Ant3D/AntAttack3D.xcodeproj/project.pbxproj"

    files_to_add = [
        "AntAttack3D/Input/InputProvider.swift",
        "AntAttack3D/Input/InputManager.swift",
    ]

    group_name = "Input"

    print("🔧 Adding Input files to Xcode project...")
    print("=" * 60)

    success = add_files_to_xcode(project_path, files_to_add, group_name)

    if success:
        print("=" * 60)
        print("✅ Done! Open Xcode to verify the files appear in the project.")
        print("   You should see an 'Input' folder in the AntAttack3D group.")
    else:
        print("=" * 60)
        print("❌ Failed to add files. Check errors above.")
        sys.exit(1)
