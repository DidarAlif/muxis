#!/usr/bin/env python3
"""
Configures generated Android scaffolding (`flutter create --platforms=android`)
with:
  1. App label ("MUXIS") and deep-link intent filter (`muxis://auth-callback`)
  2. audio_service foreground media service + MediaButtonReceiver + Android 14
     `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `FOREGROUND_SERVICE`, `WAKE_LOCK`, and
     `POST_NOTIFICATIONS` permissions
  3. MainActivity subclassing `com.ryanheise.audioservice.AudioServiceActivity`
  4. Backgroundless notification small icon (`drawable/ic_muxis_notification.png`)
"""

from pathlib import Path
import shutil


def configure_manifest(manifest_path: Path) -> None:
    text = manifest_path.read_text(encoding="utf-8")

    # 1. Ensure xmlns:tools namespace on <manifest ...> for tools:ignore
    if "xmlns:tools=" not in text:
        text = text.replace(
            "<manifest ",
            '<manifest xmlns:tools="http://schemas.android.com/tools" ',
            1,
        )

    # 2. App display name
    text = text.replace('android:label="muxis"', 'android:label="MUXIS"')

    # 3. Required background audio + notification permissions
    required_perms = [
        '<uses-permission android:name="android.permission.WAKE_LOCK"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
    ]
    missing_perms = [p for p in required_perms if p not in text]
    if missing_perms:
        perm_block = "    " + "\n    ".join(missing_perms) + "\n    <application"
        text = text.replace("<application", perm_block, 1)

    # 4. Supabase OAuth deep link (`muxis://auth-callback`) inside launcher Activity
    if 'android:scheme="muxis"' not in text:
        intent_block = (
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.VIEW"/>\n'
            '                <category android:name="android.intent.category.DEFAULT"/>\n'
            '                <category android:name="android.intent.category.BROWSABLE"/>\n'
            '                <data android:scheme="muxis" android:host="auth-callback"/>\n'
            '            </intent-filter>\n'
            '        </activity>'
        )
        text = text.replace("</activity>", intent_block, 1)

    # 5. audio_service foreground service + MediaButtonReceiver inside <application>
    if "com.ryanheise.audioservice.AudioService" not in text:
        service_block = (
            '        <service\n'
            '            android:name="com.ryanheise.audioservice.AudioService"\n'
            '            android:foregroundServiceType="mediaPlayback"\n'
            '            android:exported="true"\n'
            '            tools:ignore="Instantiatable">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.media.browse.MediaBrowserService"/>\n'
            '            </intent-filter>\n'
            '        </service>\n'
            '        <receiver\n'
            '            android:name="com.ryanheise.audioservice.MediaButtonReceiver"\n'
            '            android:exported="true">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.MEDIA_BUTTON"/>\n'
            '            </intent-filter>\n'
            '        </receiver>\n'
            '    </application>'
        )
        text = text.replace("</application>", service_block, 1)

    manifest_path.write_text(text, encoding="utf-8")


def configure_main_activity(android_src_root: Path) -> None:
    import re

    candidates = list(android_src_root.rglob("MainActivity.kt")) + list(
        android_src_root.rglob("MainActivity.java")
    )
    for activity_file in candidates:
        content = activity_file.read_text(encoding="utf-8")
        if activity_file.suffix == ".kt":
            pkg_match = re.search(r"^\s*(package\s+[^\s;]+)", content, re.MULTILINE)
            pkg_line = pkg_match.group(1) if pkg_match else "package app.muxis.muxis"
            new_content = (
                f"{pkg_line}\n\n"
                "import android.Manifest\n"
                "import android.content.pm.PackageManager\n"
                "import android.os.Build\n"
                "import android.os.Bundle\n"
                "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
                "class MainActivity : AudioServiceActivity() {\n"
                "    override fun onCreate(savedInstanceState: Bundle?) {\n"
                "        super.onCreate(savedInstanceState)\n"
                "        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {\n"
                "            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=\n"
                "                PackageManager.PERMISSION_GRANTED\n"
                "            ) {\n"
                "                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)\n"
                "            }\n"
                "        }\n"
                "    }\n"
                "}\n"
            )
            activity_file.write_text(new_content, encoding="utf-8")
        else:
            if "AudioServiceActivity" in content:
                continue
            content = content.replace(
                "import io.flutter.embedding.android.FlutterActivity;",
                "import com.ryanheise.audioservice.AudioServiceActivity;",
            ).replace(
                "extends FlutterActivity",
                "extends AudioServiceActivity",
            )
            activity_file.write_text(content, encoding="utf-8")


def configure_notification_icon(repo_root: Path) -> None:
    drawable_dir = repo_root / "android" / "app" / "src" / "main" / "res" / "drawable"
    drawable_dir.mkdir(parents=True, exist_ok=True)
    src_mark = repo_root / "assets" / "brand" / "muxis_mark_square.png"
    if not src_mark.exists():
        src_mark = repo_root / "assets" / "brand" / "muxis_mark.png"
    if src_mark.exists():
        shutil.copy2(src_mark, drawable_dir / "ic_muxis_notification.png")


def main() -> None:
    repo_root = Path.cwd()
    manifest = repo_root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    src_root = repo_root / "android" / "app" / "src" / "main"
    if manifest.exists():
        configure_manifest(manifest)
    if src_root.exists():
        configure_main_activity(src_root)
        configure_notification_icon(repo_root)
    print("Configured Android audio_service manifest, MainActivity, and notification icon.")


if __name__ == "__main__":
    main()
