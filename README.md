# godot-plugin-template

A template repository for a Godot 4+ plugin.

> [!NOTE]
> After instantiating a plugin from this repository, be sure to update placeholder text in [plugin.cfg](./plugin.cfg).

## Usage

### Add as a dependency

To use this plugin, add this repository as a submodule of a Godot project (typically under the `addons` directory). The following section lists which version should be used depending on the project's supported Godot version.

#### Branch name / Release tag: Godot version

- `main` / `v2`: `v4.4`
- `v1`: `v4.3`
- `v0`: `v4.2`

## **Development**

### Setup

The following instructions outline how to get the project set up for local development:

1. Clone this repository using the `--recurse-submodules` flag, ensuring all submodules are initialized. Alternatively, run `git submodule sync` to update all submodules to latest.
2. [Follow the instructions](https://github.com/coffeebeats/gdenv/blob/main/docs/installation.md) to install `gdenv`. Then, install the [pinned version of Godot](./.godot-version) with `gdenv i`.
3. Install the tools [used below](#code-submission) by following each of their specific installation instructions.

### Code submission

When submitting code for review, ensure the following requirements are met:

1. The project adheres as closely as possible to the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

2. The project is correctly formatted using [gdformat](https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter):

    ```sh
    bin/gdformat -l 88 --check **/*.gd
    ```

3. All [gdlint](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) linter warnings are addressed:

    ```sh
    bin/gdlint **/*.gd
    ```

4. All [Gut](https://github.com/bitwes/Gut) unit tests pass:

    ```sh
    godot \
        --quit \
        --headless \
        -s addons/gut/gut_cmdln.gd \
        -gdir="res://" \
        -ginclude_subdirs \
        -gprefix="" \
        -gsuffix="_test.gd" \
        -gexit
    ```

## **Releasing**

[Semantic Versioning](http://semver.org/) is used for versioning and [Conventional Commits](https://www.conventionalcommits.org/) is used for commit messages. A [release-please](https://github.com/googleapis/release-please) integration via [GitHub Actions](https://github.com/googleapis/release-please-action) automates releases.

### Secrets

After instantiating a project from this template repository, the default GitHub actions and workflows require the following repository secrets to be set:

- `ACTIONS_BOT_TOKEN` - If desired, create a PAT for GitHub actions to use when checking a project; allows fix-formatting commits to trigger actions.

### Customization

In addition to [Secrets](#secrets), the following files should be customized for the instantiated repository:

- [plugin.cfg](./plugin.cfg) - update the title, description, and other properties of the plugin configuration file.
- [.github/workflows/release-please.yml](.github/workflows/release-please.yml) - ensure the project is correctly packaged into an addon.

Also update repository settings in GitHub, including:

- General repository features
- Branch protection for `main` and `godot-v4.*` release branches

## **Version history**

See [CHANGELOG.md](https://github.com/coffeebeats/godot-plugin-template/blob/main/CHANGELOG.md).

## **License**

> [!IMPORTANT]
> After instantiating this repository, consider removing this license if the project isn't intended to be open source.

[MIT License](https://github.com/coffeebeats/godot-plugin-template/blob/main/LICENSE)
