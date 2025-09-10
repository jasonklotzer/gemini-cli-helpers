# Gemini CLI Helpers

This project is a collection of shell scripts that leverage the Gemini CLI to automate common developer tasks.

## Installation

To install the scripts and make them available as commands in your shell, run the following command from the root of the project directory:

```bash
./install.sh
```

This will:
- Create aliases for all scripts in the `scripts` directory.
- Add the aliases to your `~/.bash_aliases` file.
- Ensure `~/.bash_aliases` is sourced by your `~/.bashrc`.

After installation, you'll need to restart your shell or source your `.bashrc` file for the changes to take effect:

```bash
source ~/.bashrc
```

## Available Scripts

### gemit

The `gemit` script automates the process of generating a commit message for your staged changes using the Gemini CLI.

**Usage:**

1.  Stage the changes you want to commit (`git add .`).
2.  Run the `gemit` command:

    ```bash
    gemit
    ```

The script will use the staged diff to generate a concise commit message and then create the commit.
