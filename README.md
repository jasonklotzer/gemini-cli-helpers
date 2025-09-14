# Gemini CLI Helpers

This project is a collection of shell scripts that leverage the Gemini CLI to automate common developer tasks.

## Installation

There are two ways to install these helper scripts.

### Using npm (recommended)

If you have Node.js and npm installed, you can install the scripts globally from the root of the project directory:

```bash
npm install -g .
```

This will make the `gemit` command available in your system's path.

### Using Bash script

For bash users who prefer not to install a global npm package, you can use the provided bash script to create an alias.

```bash
./install-bash.sh
```

This will:
- Create an alias for the `gemit` script in the `scripts` directory.
- Add the alias to your `~/.bash_aliases` file.
- Ensure `~/.bash_aliases` is sourced by your `~/.bashrc`.

After installation, you'll need to restart your shell or source your `.bashrc` file for the changes to take effect:

```bash
source ~/.bashrc
```

## Available Scripts

### gemit

The `gemit` script automates the process of generating a commit message for your staged changes using the Gemini CLI.

**Usage:**

```bash
gemit [options]
```

The script will use the staged diff to generate a concise commit message and then create the commit.

**Options:**

| Option             | Description                                                                      |
| ------------------ | -------------------------------------------------------------------------------- |
| `-h`, `--help`     | Show the help message and exit.                                                  |
| `-a`, `--all`      | Stage all tracked files before committing.                                       |
| `-s`, `--submodule`| If in a submodule, commit the submodule changes in the parent repository as well. |

**Examples:**

-   Generate a commit message for currently staged files:
    ```bash
    git add .
    gemit
    ```

-   Stage all files and generate a commit message:
    ```bash
    gemit -a
    ```

-   Stage all files and commit submodule changes in the parent repository:
    ```bash
    gemit -a -s
    ```
