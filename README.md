# 🚀 Solid Clean CLI - Dart Command-Line Toolkit

🎉 **Welcome to Solid Clean CLI!** Dive into a well-structured Dart command-line application. Built with the intention of demonstrating separation of concerns, it's neatly organized into specific directories to ensure scalability and maintainability.

## 📂 Directory Overview

- **`bin/`**: Here's where the magic starts — the application's entry point.
- **`lib/`**: Dive into the heart of the application. This is where all the library code resides.
- **`test/`**: Put the code to the test! This directory houses all the unit tests.

## ⚙️ Setup & Usage

Get the Solid Clean CLI up and running in a jiffy with these easy steps:
### Step 0: add dependency in pubspec.yml
```bash
  clean_arch:
    git: https://github.com/cg-tushar/clean_arch.git
```

### Step 1: Compile the Application
Transform the Dart code into a nifty executable:

```bash
dart compile exe bin/solid_clean_cli.dart -o solid
```
### Step 2: Make it Globally Accessible

```bash
sudo mv solid /usr/local/bin/
```
### Step 3: Create screen with all componenets

```bash
solid create screen:Homepage

