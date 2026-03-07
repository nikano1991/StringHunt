# StringHunt
This project is based on [abandoned-strings](https://github.com/ijoshsmith/abandoned-strings) by [@ijoshsmith](https://github.com/ijoshsmith).

A Swift command-line tool to find unused localized strings in iOS/macOS projects.

## Description

StringHunt scans your Xcode project to identify localized strings (from `.strings` files) that are not being used anywhere in your codebase. This helps keep your localization files clean and reduces app bundle size by removing dead strings.

## Features

- Scans `.strings` files for all defined localization keys
- Searches through Swift, Objective-C, and optionally Storyboard/XIB files
- Supports ignoring specific `.strings` files
- Outputs a list of unused string keys

## Requirements

- macOS
- Swift 5.0+

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/MarcGarciaSunweb/StringHunt.git
   cd StringHunt
   ```

2. Make the script executable:
   ```bash
   chmod +x main.swift
   ```

## Usage

```bash
./main.swift <project-path> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<project-path>` | Path to the root directory of your Xcode project |

### Options

| Option | Description |
|--------|-------------|
| `--ignore=<filename>` | Ignore a specific `.strings` file (e.g., `--ignore=FCLocalizable.strings`) |
| `--include-storyboards` | Include Storyboard and XIB files in the search for string usage |

### Examples

**Basic usage:**
```bash
./main.swift /path/to/your/project
```

**Ignore a specific strings file:**
```bash
./main.swift /path/to/your/project --ignore=FCLocalizable.strings
```

**Include storyboards in the search:**
```bash
./main.swift /path/to/your/project storyboards
```

**Combine options:**
```bash
./main.swift /path/to/your/project --ignore=FCLocalizable.strings storyboards
```

## Output

The tool outputs a list of unused string keys to the console. You can redirect the output to a file if needed:

```bash
./main.swift /path/to/your/project > unused_strings.txt
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
