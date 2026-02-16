#!/bin/bash

echo "========================================"
echo "FPDI Installation Fix for PHP 7.4+"
echo "========================================"
echo ""

# Check if composer is installed
if ! command -v composer &> /dev/null; then
    echo "ERROR: Composer is not installed"
    echo ""
    echo "Install Composer first:"
    echo "curl -sS https://getcomposer.org/installer | php"
    echo "sudo mv composer.phar /usr/local/bin/composer"
    echo ""
    exit 1
fi

echo "Composer found!"
echo ""

# Check PHP version
PHP_VERSION=$(php -r "echo PHP_VERSION;")
echo "PHP Version: $PHP_VERSION"
echo ""

# Remove old installation
if [ -d "vendor" ]; then
    echo "Removing old vendor directory..."
    rm -rf vendor
fi

if [ -f "composer.lock" ]; then
    echo "Removing old composer.lock..."
    rm composer.lock
fi

echo ""
echo "Installing FPDI 2.3.x (compatible with PHP 7.4+)..."
echo ""

# Install FPDI 2.3.x
composer require setasign/fpdi:^2.3

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "SUCCESS! FPDI 2.3.x installed"
    echo "========================================"
    echo ""
    echo "You can now use the PDF merge functionality."
    echo ""
    echo "Test it by visiting:"
    echo "https://your-server.com/test_merge_poe.php"
    echo ""
else
    echo ""
    echo "========================================"
    echo "Installation failed!"
    echo "========================================"
    echo ""
    echo "Try manual installation:"
    echo "1. Delete vendor folder and composer.lock"
    echo "2. Run: composer install --ignore-platform-reqs"
    echo ""
    exit 1
fi
