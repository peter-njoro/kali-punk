# Multi-Distro Installer

This project provides a simple way to install a set of predefined packages and configurations on both Arch Linux and Debian-based systems. The installation process is automated through scripts that detect the operating system and execute the appropriate installation commands.

## Project Structure

- **bin/**: Contains the main installation scripts.
  - `install.sh`: The main script that detects the OS and calls the appropriate installation script.
  - `install-arch.sh`: Installation script for Arch Linux.
  - `install-debian.sh`: Installation script for Debian-based systems.

- **scripts/**: Contains utility scripts.
  - `detect_os.sh`: Detects the operating system.
  - `common.sh`: Contains common functions and variables.

- **packages/**: Contains text files listing the packages to be installed.
  - `arch.txt`: Packages for Arch Linux.
  - `debian.txt`: Packages for Debian-based systems.

- **templates/**: Contains configuration templates.
  - `config/polybar/panels/panel.ini`: Template for Polybar panel configuration.

- **.gitignore**: Specifies files and directories to be ignored by Git.

- **LICENSE**: Licensing information for the project.

## Installation Instructions

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/multi-distro-installer.git
   cd multi-distro-installer
   ```

2. Make the installation script executable:
   ```
   chmod +x bin/install.sh
   ```

3. Run the installation script:
   ```
   ./bin/install.sh
   ```

The script will automatically detect your operating system and install the necessary packages based on the detected OS.

## Usage

After installation, you can customize the configuration files located in the `templates/config/` directory. The installation script will copy the necessary configuration files to the appropriate directories based on your system.

## Contributing

Feel free to submit issues or pull requests if you have suggestions or improvements for the project.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.