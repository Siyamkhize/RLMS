#!/bin/bash
# Install FPDI Library for PDF Merging
# Run this on your server

echo "Installing FPDI Library for PDF Merging..."

# Check if composer is installed
if ! command -v composer &> /dev/null; then
    echo "Composer not found. Installing composer..."
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/local/bin/composer
fi

# Install FPDI
echo "Installing FPDI via Composer..."
composer require setasign/fpdi

echo "✅ FPDI installed successfully!"
echo ""
echo "Next steps:"
echo "1. Upload merge_poe_documents.php to your server"
echo "2. Test the merge endpoint"
echo "3. Update your Flutter app"
echo ""
echo "Test command:"
echo "curl -X POST https://tesing.mtltechnical.co.za/mobile/merge_poe_documents.php \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"document_ids\":[1,2],\"learner_id\":\"12345\"}'"
