#!/usr/bin/env python3
"""Regenerates WidgetForge.xcodeproj from the folders next to it.

    python3 tools/generate_xcodeproj.py

Only the Python standard library is needed. Re-run it after adding, renaming or removing
Swift files in App/, Widget/ or Shared/. (If you prefer to work inside Xcode, just add files
there and ignore this script.)

What it builds:
  * WidgetForge           - the iOS app        (App/ + Shared/)
  * WidgetForgeExtension  - the widget bundle  (Widget/ + Shared/), embedded in the app

Shared/ is compiled into both targets, so the editor and the Home Screen widget draw
designs with exactly the same code.
"""

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = "WidgetForge"
EXT = "WidgetForgeExtension"
DEPLOYMENT_TARGET = "17.0"

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcconfig": "text.xcconfig",
    ".xcassets": "folder.assetcatalog",
    ".xcprivacy": "text.plist.xml",
}

# ----------------------------------------------------------------------------------------
# Object registry
# ----------------------------------------------------------------------------------------

objects = {}  # id -> dict (always has "isa")
comments = {}  # id -> text shown after the id, as Xcode does
ref_keys = {}  # file reference id -> stable key (used to derive build file ids)
_used_ids = {}


def oid(key):
    """A stable 24-hex-digit identifier derived from a unique key."""
    value = hashlib.md5(("WidgetForge/" + key).encode("utf-8")).hexdigest()[:24].upper()
    if _used_ids.setdefault(value, key) != key:
        raise SystemExit("identifier collision between %r and %r" % (key, _used_ids[value]))
    return value


def add(key, isa, comment=None, **fields):
    identifier = oid(key)
    objects[identifier] = dict(isa=isa, **fields)
    if comment:
        comments[identifier] = comment
    return identifier


# ----------------------------------------------------------------------------------------
# Object helpers
# ----------------------------------------------------------------------------------------


def file_ref(key, path, explicit=None, include_in_index=None, source_tree="<group>", name=None):
    fields = {}
    if explicit:
        fields["explicitFileType"] = explicit
    else:
        file_type = FILE_TYPES.get(Path(path).suffix)
        if file_type:
            fields["lastKnownFileType"] = file_type
    if include_in_index is not None:
        fields["includeInIndex"] = include_in_index
    if name:
        fields["name"] = name
    fields["path"] = path
    fields["sourceTree"] = source_tree
    identifier = add(key, "PBXFileReference", comment=name or Path(path).name, **fields)
    ref_keys[identifier] = key
    return identifier


def group(key, children, path=None, name=None):
    fields = {"children": children}
    if name:
        fields["name"] = name
    if path:
        fields["path"] = path
    fields["sourceTree"] = "<group>"
    return add(key, "PBXGroup", comment=name or path, **fields)


def build_file(key, ref, phase_name, settings=None):
    fields = {"fileRef": ref}
    if settings:
        fields["settings"] = settings
    return add(key, "PBXBuildFile", comment="%s in %s" % (comments[ref], phase_name), **fields)


def build_phase(key, isa, title, files, **extra):
    return add(
        key,
        isa,
        comment=title,
        buildActionMask=2147483647,
        files=files,
        runOnlyForDeploymentPostprocessing=0,
        **extra
    )


def configuration(key, name, settings, base_reference=None):
    fields = {}
    if base_reference:
        fields["baseConfigurationReference"] = base_reference
    fields["buildSettings"] = settings
    fields["name"] = name
    return add(key, "XCBuildConfiguration", comment=name, **fields)


def configuration_list(key, owner_kind, owner_name, settings_debug, settings_release, base_reference=None):
    debug = configuration(key + "/debug", "Debug", settings_debug, base_reference)
    release = configuration(key + "/release", "Release", settings_release, base_reference)
    return add(
        key,
        "XCConfigurationList",
        comment='Build configuration list for %s "%s"' % (owner_kind, owner_name),
        buildConfigurations=[debug, release],
        defaultConfigurationIsVisible=0,
        defaultConfigurationName="Release",
    )


# ----------------------------------------------------------------------------------------
# Source tree discovery
# ----------------------------------------------------------------------------------------


def source_tree(key_prefix, directory):
    """A PBXGroup mirroring `directory`, containing every .swift file below it.

    Returns (group_id or None, [file reference ids])."""
    children, refs = [], []
    entries = sorted(directory.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))
    for entry in entries:
        if entry.name.startswith("."):
            continue
        entry_key = key_prefix + "/" + entry.name
        if entry.is_dir():
            sub_group, sub_refs = source_tree(entry_key, entry)
            if sub_group:
                children.append(sub_group)
                refs.extend(sub_refs)
        elif entry.suffix == ".swift":
            ref = file_ref(entry_key, entry.name)
            children.append(ref)
            refs.append(ref)
    if not children:
        return None, []
    return group(key_prefix, children, path=directory.name), refs


# ----------------------------------------------------------------------------------------
# Build the project
# ----------------------------------------------------------------------------------------


def main():
    for folder in ("App", "Widget", "Shared", "Resources", "Config"):
        if not (ROOT / folder).is_dir():
            sys.exit("missing folder: %s" % (ROOT / folder))

    project_id = oid("project")
    app_id = oid("target/app")
    ext_id = oid("target/ext")
    comments[project_id] = "Project object"

    # Source groups (Swift files are discovered, so new files are picked up automatically).
    app_group, app_refs = source_tree("App", ROOT / "App")
    widget_group, widget_refs = source_tree("Widget", ROOT / "Widget")
    shared_group, shared_refs = source_tree("Shared", ROOT / "Shared")
    if not (app_refs and widget_refs and shared_refs):
        sys.exit("expected Swift files in App/, Widget/ and Shared/")

    # Resources and configuration.
    assets = file_ref("Resources/Assets.xcassets", "Assets.xcassets")
    app_plist = file_ref("Resources/app-plist", "%s-Info.plist" % APP)
    ext_plist = file_ref("Resources/ext-plist", "%s-Info.plist" % EXT)
    app_entitlements = file_ref("Resources/app-entitlements", "%s.entitlements" % APP)
    ext_entitlements = file_ref("Resources/ext-entitlements", "%s.entitlements" % EXT)
    privacy_manifest = file_ref("Resources/privacy", "PrivacyInfo.xcprivacy")
    resources_group = group(
        "Resources",
        [assets, app_plist, app_entitlements, ext_plist, ext_entitlements, privacy_manifest],
        path="Resources",
    )
    xcconfig = file_ref("Config/xcconfig", "WidgetForge.xcconfig")
    config_group = group("Config", [xcconfig], path="Config")

    # System frameworks linked into the widget extension.
    frameworks = [
        file_ref(
            "Frameworks/" + name,
            "System/Library/Frameworks/%s.framework" % name,
            explicit=None,
            source_tree="SDKROOT",
            name="%s.framework" % name,
        )
        for name in ("WidgetKit", "SwiftUI", "AppIntents")
    ]
    for ref in frameworks:
        objects[ref]["lastKnownFileType"] = "wrapper.framework"
    frameworks_group = group("Frameworks", frameworks, name="Frameworks")

    # Products.
    app_product = file_ref(
        "Products/app", "%s.app" % APP, explicit="wrapper.application", include_in_index=0,
        source_tree="BUILT_PRODUCTS_DIR",
    )
    ext_product = file_ref(
        "Products/ext", "%s.appex" % EXT, explicit="wrapper.app-extension", include_in_index=0,
        source_tree="BUILT_PRODUCTS_DIR",
    )
    products_group = group("Products", [app_product, ext_product], name="Products")

    main_group = add(
        "group/main",
        "PBXGroup",
        children=[
            app_group, widget_group, shared_group, resources_group, config_group,
            frameworks_group, products_group,
        ],
        sourceTree="<group>",
    )

    # --- Build phases: widget extension -------------------------------------------------
    ext_sources = build_phase(
        "ext/sources", "PBXSourcesBuildPhase", "Sources",
        [build_file("ext/src/" + ref_keys[r], r, "Sources") for r in shared_refs + widget_refs],
    )
    ext_frameworks = build_phase(
        "ext/frameworks", "PBXFrameworksBuildPhase", "Frameworks",
        [build_file("ext/fw/" + ref_keys[r], r, "Frameworks") for r in frameworks],
    )
    ext_resources = build_phase(
        "ext/resources", "PBXResourcesBuildPhase", "Resources",
        [build_file("ext/res/privacy", privacy_manifest, "Resources")],
    )

    # --- Build phases: app --------------------------------------------------------------
    app_sources = build_phase(
        "app/sources", "PBXSourcesBuildPhase", "Sources",
        [build_file("app/src/" + ref_keys[r], r, "Sources") for r in shared_refs + app_refs],
    )
    app_frameworks = build_phase("app/frameworks", "PBXFrameworksBuildPhase", "Frameworks", [])
    app_resources = build_phase(
        "app/resources", "PBXResourcesBuildPhase", "Resources",
        [
            build_file("app/res/assets", assets, "Resources"),
            build_file("app/res/privacy", privacy_manifest, "Resources"),
        ],
    )
    embed_file = build_file(
        "app/embed/ext", ext_product, "Embed Foundation Extensions",
        settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]},
    )
    app_embed = build_phase(
        "app/embed", "PBXCopyFilesBuildPhase", "Embed Foundation Extensions", [embed_file],
        dstPath="", dstSubfolderSpec=13, name="Embed Foundation Extensions",
    )

    # --- Target dependency: the app builds the extension first --------------------------
    proxy = add(
        "app/dependency/proxy", "PBXContainerItemProxy", comment="PBXContainerItemProxy",
        containerPortal=project_id, proxyType=1, remoteGlobalIDString=ext_id, remoteInfo=EXT,
    )
    dependency = add(
        "app/dependency", "PBXTargetDependency", comment="PBXTargetDependency",
        target=ext_id, targetProxy=proxy,
    )

    # --- Build settings -----------------------------------------------------------------
    project_common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0",
    }
    project_debug = dict(
        project_common,
        DEBUG_INFORMATION_FORMAT="dwarf",
        ENABLE_TESTABILITY="YES",
        GCC_OPTIMIZATION_LEVEL="0",
        ONLY_ACTIVE_ARCH="YES",
        SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG $(inherited)",
        SWIFT_OPTIMIZATION_LEVEL="-Onone",
    )
    project_release = dict(
        project_common,
        DEBUG_INFORMATION_FORMAT="dwarf-with-dsym",
        ENABLE_NS_ASSERTIONS="NO",
        SWIFT_COMPILATION_MODE="wholemodule",
        VALIDATE_PRODUCT="YES",
    )

    app_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_ENTITLEMENTS": "Resources/%s.entitlements" % APP,
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "Resources/%s-Info.plist" % APP,
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
        "MARKETING_VERSION": "2.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "$(APP_BUNDLE_ID)",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    ext_settings = {
        "CODE_SIGN_ENTITLEMENTS": "Resources/%s.entitlements" % EXT,
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "Resources/%s-Info.plist" % EXT,
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "MARKETING_VERSION": "2.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "$(APP_BUNDLE_ID).Widget",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SKIP_INSTALL": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }

    project_configs = configuration_list(
        "config/project", "PBXProject", APP, project_debug, project_release, base_reference=xcconfig
    )
    app_configs = configuration_list(
        "config/app", "PBXNativeTarget", APP, app_settings, app_settings
    )
    ext_configs = configuration_list(
        "config/ext", "PBXNativeTarget", EXT, ext_settings, ext_settings
    )

    # --- Targets ------------------------------------------------------------------------
    add(
        "target/ext", "PBXNativeTarget", comment=EXT,
        buildConfigurationList=ext_configs,
        buildPhases=[ext_sources, ext_frameworks, ext_resources],
        buildRules=[], dependencies=[], name=EXT, productName=EXT,
        productReference=ext_product, productType="com.apple.product-type.app-extension",
    )
    add(
        "target/app", "PBXNativeTarget", comment=APP,
        buildConfigurationList=app_configs,
        buildPhases=[app_sources, app_frameworks, app_resources, app_embed],
        buildRules=[], dependencies=[dependency], name=APP, productName=APP,
        productReference=app_product, productType="com.apple.product-type.application",
    )

    # --- Project ------------------------------------------------------------------------
    add(
        "project", "PBXProject", comment="Project object",
        attributes={
            "BuildIndependentTargetsInParallel": 1,
            "LastSwiftUpdateCheck": 2600,
            "LastUpgradeCheck": 2600,
            "TargetAttributes": {
                app_id: {"CreatedOnToolsVersion": "15.0"},
                ext_id: {"CreatedOnToolsVersion": "15.0"},
            },
        },
        buildConfigurationList=project_configs,
        compatibilityVersion="Xcode 14.0",
        developmentRegion="en",
        hasScannedForEncodings=0,
        knownRegions=["en", "Base"],
        mainGroup=main_group,
        productRefGroup=products_group,
        projectDirPath="",
        projectRoot="",
        targets=[app_id, ext_id],
    )

    verify(project_id)
    write_project(project_id, app_id)
    print("Generated %s.xcodeproj" % APP)
    print("  app sources:       %d files" % len(shared_refs + app_refs))
    print("  extension sources: %d files" % len(shared_refs + widget_refs))


# ----------------------------------------------------------------------------------------
# Self-check
# ----------------------------------------------------------------------------------------

ID_PATTERN = re.compile(r"^[0-9A-F]{24}$")


def verify(project_id):
    """Every identifier mentioned anywhere must belong to an object in the project."""

    def walk(value, owner):
        if isinstance(value, dict):
            for k, v in value.items():
                if isinstance(k, str) and ID_PATTERN.match(k) and k not in objects:
                    raise SystemExit("%s: dangling key %s" % (owner, k))
                walk(v, owner)
        elif isinstance(value, list):
            for item in value:
                walk(item, owner)
        elif isinstance(value, str) and ID_PATTERN.match(value) and value not in objects:
            raise SystemExit("%s: dangling reference %s" % (owner, value))

    for identifier, obj in objects.items():
        walk(obj, "%s %s" % (obj["isa"], identifier))
    if objects[project_id]["isa"] != "PBXProject":
        raise SystemExit("project object missing")


# ----------------------------------------------------------------------------------------
# Serialisation (Xcode's old-style property list format)
# ----------------------------------------------------------------------------------------

SAFE = re.compile(r"^[A-Za-z0-9_./]+$")


def quote(text):
    if text and SAFE.match(text) and not text.startswith("//"):
        return text
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def scalar(value):
    if isinstance(value, bool):
        raise TypeError("booleans are not used in project files")
    if isinstance(value, int):
        return str(value)
    text = quote(str(value))
    if isinstance(value, str) and ID_PATTERN.match(value) and value in comments:
        text += " /* %s */" % comments[value]
    return text


def key_text(key):
    text = quote(key)
    if ID_PATTERN.match(key) and key in comments:
        text += " /* %s */" % comments[key]
    return text


def ordered(mapping):
    return sorted(mapping.items(), key=lambda item: (item[0] != "isa", item[0]))


def inline(value):
    if isinstance(value, dict):
        return "{" + "".join("%s = %s; " % (key_text(k), inline(v)) for k, v in ordered(value)) + "}"
    if isinstance(value, list):
        return "(" + "".join("%s, " % inline(v) for v in value) + ")"
    return scalar(value)


def block(value, level):
    pad = "\t" * level
    if isinstance(value, dict):
        if not value:
            return "{\n%s}" % pad
        lines = ["{"]
        for k, v in ordered(value):
            lines.append("%s\t%s = %s;" % (pad, key_text(k), block(v, level + 1)))
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        if not value:
            return "(\n%s)" % pad
        lines = ["("]
        for item in value:
            lines.append("%s\t%s," % (pad, block(item, level + 1)))
        lines.append(pad + ")")
        return "\n".join(lines)
    return scalar(value)


def write_project(project_id, app_id):
    out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};",
           "\tobjectVersion = 56;", "\tobjects = {", ""]
    by_isa = {}
    for identifier, obj in objects.items():
        by_isa.setdefault(obj["isa"], []).append(identifier)
    for isa in sorted(by_isa):
        out.append("/* Begin %s section */" % isa)
        for identifier in sorted(by_isa[isa]):
            obj = objects[identifier]
            label = identifier + (" /* %s */" % comments[identifier] if identifier in comments else "")
            if isa in ("PBXBuildFile", "PBXFileReference"):
                out.append("\t\t%s = %s;" % (label, inline(obj)))
            else:
                out.append("\t\t%s = %s;" % (label, block(obj, 2)))
        out.append("/* End %s section */" % isa)
        out.append("")
    out.append("\t};")
    out.append("\trootObject = %s /* Project object */;" % project_id)
    out.append("}")

    bundle = ROOT / ("%s.xcodeproj" % APP)
    (bundle / "project.xcworkspace").mkdir(parents=True, exist_ok=True)
    (bundle / "xcshareddata" / "xcschemes").mkdir(parents=True, exist_ok=True)
    (bundle / "project.pbxproj").write_text("\n".join(out) + "\n", encoding="utf-8")
    (bundle / "project.xcworkspace" / "contents.xcworkspacedata").write_text(WORKSPACE, encoding="utf-8")
    scheme = SCHEME.replace("@@APP_ID@@", app_id).replace("@@APP@@", APP)
    (bundle / "xcshareddata" / "xcschemes" / ("%s.xcscheme" % APP)).write_text(scheme, encoding="utf-8")


WORKSPACE = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "@@APP_ID@@"
               BuildableName = "@@APP@@.app"
               BlueprintName = "@@APP@@"
               ReferencedContainer = "container:@@APP@@.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "@@APP_ID@@"
            BuildableName = "@@APP@@.app"
            BlueprintName = "@@APP@@"
            ReferencedContainer = "container:@@APP@@.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "@@APP_ID@@"
            BuildableName = "@@APP@@.app"
            BlueprintName = "@@APP@@"
            ReferencedContainer = "container:@@APP@@.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


if __name__ == "__main__":
    main()
