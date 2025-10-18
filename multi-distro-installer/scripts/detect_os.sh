#!/usr/bin/env bash

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            arch)
                echo "arch"
                ;;
            debian)
                echo "debian"
                ;;
            ubuntu)
                echo "debian"
                ;;
            *)
                echo "unsupported"
                ;;
        esac
    else
        echo "unsupported"
    fi
}

OS=$(detect_os)
echo $OS