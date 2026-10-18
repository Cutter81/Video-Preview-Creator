# Video Preview Creator v1.2

**Video Preview Creator** is a Windows utility by Cutter81 that creates MP4 video previews for RetroBat collections. For each supported video file in a selected folder, it creates a preview in the collection's `media\videos` directory.

For videos longer than 30 seconds, it normally chooses a **random 30-second segment** from the video, avoiding the first and last 30 seconds whenever the video is long enough. Videos that are 30 seconds or shorter are converted in full to MP4.

## Features

- Creates one MP4 preview for each supported video file.
- Chooses a random 30-second section for longer videos when there is enough footage to avoid the first and last 30 seconds.
- Uses a centered 30-second section for videos longer than 30 seconds but shorter than 90 seconds, where avoiding both 30-second end sections is not possible.
- Preserves videos of 30 seconds or less in full, converting them to MP4.
- Keeps the original video files unchanged.
- Shows progress and an activity log in the application window.
- Writes a persistent text log in the selected source folder.
- Skips an output if a file with the same output name already exists, rather than overwriting it.

## Requirements

- Windows.
- **FFmpeg** and **FFprobe** installed and available on your system `PATH`.
- A folder containing the video files you want to process.

The application checks for both `ffmpeg` and `ffprobe` before processing. If either is unavailable, it displays an error and does not process any files.

## How to Use

1. Launch **Video Preview Creator**.
2. Click **Browse...** and select the folder containing the source video files.
3. Check the displayed output path.
4. Click **Create Previews**.
5. Watch the progress bar and activity log for the result of each file.

The tool processes supported video files directly inside the selected source folder; it does not recursively scan subfolders.

## Preview Selection

The preview duration is 30 seconds.

- **Videos 90 seconds or longer:** a random start time is selected so the 30-second preview avoids the first and final 30 seconds.
- **Videos longer than 30 seconds but shorter than 90 seconds:** a centered 30-second segment is used as a fallback.
- **Videos 30 seconds or shorter:** the entire video is converted to MP4 rather than trimmed to a 30-second segment.

The random segment is selected when the tool processes the file. Running the tool again will not replace an existing preview automatically; existing outputs are skipped.

## Supported Video Formats

The tool recognizes these filename extensions (case-insensitive):

`.mp4`, `.mkv`, `.avi`, `.mov`, `.wmv`, `.flv`, `.webm`, `.m4v`, `.mpg`, `.mpeg`, `.ts`, `.mts`, `.m2ts`, `.vob`, `.ogv`, `.3gp`

FFmpeg must be able to read the actual video and its codecs for processing to succeed.

## Output Location and Names

Previews are written to:

`<selected source folder>\media\videos`

The output filename is the source filename with its extension changed to `.mp4`.

Example:

- Source: `Example Game.mkv`
- Output: `media\videos\Example Game.mp4`

If the output file already exists, the application logs that it skipped the file and does not overwrite it. This also means two source files with the same filename stem but different extensions would target the same output filename; process those carefully if both need separate previews.

## Activity Log

The application displays per-file status messages and a final count of created, skipped, and failed files. It also appends a text log to:

`<selected source folder>\000-VideoPeviewCreator.txt`

The filename used by the program is `000-VideoPeviewCreator.txt` (with “Peview” as spelled in the current application source).

## Troubleshooting

- **FFmpeg or FFprobe not found:** Install FFmpeg and make sure both `ffmpeg.exe` and `ffprobe.exe` are available through `PATH`, then restart the application.
- **No supported videos found:** Confirm that supported video files are directly inside the selected source folder, not only in subfolders.
- **A file was skipped because the duration could not be determined:** Check whether FFprobe can read the file and whether the video is valid.
- **An existing output was skipped:** The corresponding MP4 already exists. The tool intentionally avoids overwriting it; move or rename the existing output if you want to generate it again.
- **A file failed:** Check the activity log for FFmpeg's error details, including unsupported or damaged source media.

## Included Files

- `VideoPreviewCreator.ps1` — PowerShell application source.
- `VideoPreviewCreatorLauncher.cs` — C# launcher source used to package the application.
- `Build-VideoPreviewCreator-EXE-with-RazorBlade.bat` — batch file for building the executable.
- `VideoPreviewCreator-RazorBlade.ico` — application icon.

The build batch file uses the .NET Framework C# compiler included with supported Windows .NET Framework installations. FFmpeg and FFprobe are runtime requirements and are not bundled by the build script.

## Notes

- Source videos are read, not modified.
- Preview files are encoded as MP4 using H.264 video and AAC audio settings.
- The utility does not overwrite an existing preview file.

## Credits

**Video Preview Creator v1.2 by Cutter81**
