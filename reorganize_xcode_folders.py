#!/usr/bin/env python3
"""
Script to reorganize Xcode project folders after moving files
"""

import os
import re


def reorganize_xcode_folders(project_path):
    """
    Update Xcode project.pbxproj to reflect new folder structure
    """

    print(f"📝 Reading project file: {project_path}")
    with open(project_path, "r") as f:
        content = f.read()

    # Define folder mappings (old filename -> new path)
    folder_mappings = {
        "AppDelegate3D.swift": "App",
        "MainNavigationController.swift": "App",
        "TitleScene3D.swift": "Scenes",
        "GameScene3D.swift": "Scenes",
        "AboutScene3D.swift": "Scenes",
        "LeaderboardScene3D.swift": "Scenes",
        "GameViewController3D.swift": "ViewControllers",
        "EnemyBall.swift": "Entities",
        "Hostage.swift": "Entities",
        "CityMap3D.swift": "World",
        "ConfigManager.swift": "Services",
        "GameCenterManager.swift": "Services",
    }

    print(f"\n🔄 Updating file paths in project...")

    # Update file references
    for filename, folder in folder_mappings.items():
        # Pattern: filename with path attribute
        pattern = (
            rf"(/\* {re.escape(filename)} \*/ = {{[^}}]*path = ){re.escape(filename)};"
        )
        replacement = rf"\1{folder}/{filename};"

        old_content = content
        content = re.sub(pattern, replacement, content)

        if content != old_content:
            print(f"   ✅ {filename:40} → {folder}/")
        else:
            print(f"   ⚠️  {filename:40} (not found or already updated)")

    # Write updated project file
    with open(project_path, "w") as f:
        f.write(content)

    print(f"\n✅ Project file updated successfully!")
    return True


if __name__ == "__main__":
    project_path = "/Users/jonathanoliver/Ant3D/AntAttack3D.xcodeproj/project.pbxproj"

    print("🔧 Reorganizing Xcode project folders...")
    print("=" * 80)

    success = reorganize_xcode_folders(project_path)

    if success:
        print("=" * 80)
        print("✅ Done! File paths updated in Xcode project.")
        print("   Note: You'll need to update group structure in Xcode manually")
        print("   or add groups using the add_files_to_xcode.py script.")
    else:
        print("=" * 80)
        print("❌ Failed to reorganize folders.")
