#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 -u <QT_USER> -p <QT_PASSWORD>"
    exit 1
}

# Parse arguments
while getopts "u:p:" opt; do
    case $opt in
        u) QT_USER=$OPTARG ;;
        p) QT_PASSWORD=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if QT_USER and QT_PASSWORD are set
if [ -z "$QT_USER" ] || [ -z "$QT_PASSWORD" ]; then
    usage
fi

# Check if QT_USER and QT_PASSWORD are not placeholder values
if [ "$QT_USER" == "your_qt_username" ] || [ "$QT_PASSWORD" == "your_qt_password" ]; then
    echo "Error: QT_USER and QT_PASSWORD cannot be the placeholder values from the README file."
    usage
fi

# Prompt user for license agreement acceptance
echo "Qt Open Source version is available under GNU General Public License v3 and Lesser GNU General Public License v3. A few components are available under GNU General Public License v2."
echo "Read and accept the Open Source Usage Obligations below. Reading the link below helps you choosing the right license for your project."
echo ""
echo "Choosing the right license for your projects: https://www.qt.io/licensing"
echo "Buy Qt: https://www.qt.io/buy-product"
echo ""
echo "(Lesser) GNU General Public License v3 obligations:"
echo ""
echo "* You must not combine code developed with a commercial Qt license with code developed with an open source license of Qt in one project or product"
echo "* Provide a license copy & explicitly acknowledge Qt use"
echo "* Make a Qt source code copy available for customers"
echo "* Accept that Qt source code modifications are non-proprietary"
echo "* Make consumer devices, which allow users to access to install and run modified versions of the SW inside them"
echo "* Accept Digital Rights Management terms, see the GPL FAQ: http://www.gnu.org/licenses/gpl-faq.html#DRMProhibited"
echo "* Take special consideration when attempting to enforce software patents: https://www.gnu.org/licenses/gpl-faq.html#v3PatentRetaliation"
echo "* For further information, refer to GPLv3: https://www.gnu.org/licenses/gpl-3.0.html and GPLv3: https://www.gnu.org/licenses/lgpl-3.0.en.html"
echo ""
read -p "Accept|Reject: " LICENSE_PROMPT

# Capitalize the first letter of the user's response
LICENSE_PROMPT="$(tr '[:lower:]' '[:upper:]' <<< ${LICENSE_PROMPT:0:1})${LICENSE_PROMPT:1}"

if [[ "$LICENSE_PROMPT" != "Accept" ]]; then
    echo "Warning: Open Source obligations not accepted by user. Aborting."
    exit 1
fi

# Loop until a valid response is provided for the telemetry question
while true; do
    echo "telemetry-question : Contribute to Qt Development : Help us improve Qt and Qt Creator by allowing tracking of pseudonymous usage data in Qt Creator. The tracking can be disabled at any time. Read the Qt Company data collection privacy statement https://www.qt.io/terms-conditions/#privacy."
    read -p "Yes|No: " TELEMETRY_PROMPT

    # Capitalize the first letter of the user's response
    TELEMETRY_PROMPT="$(tr '[:lower:]' '[:upper:]' <<< ${TELEMETRY_PROMPT:0:1})${TELEMETRY_PROMPT:1}"

    if [[ "$TELEMETRY_PROMPT" == "Yes" || "$TELEMETRY_PROMPT" == "No" ]]; then
        break
    else
        echo "Invalid answer, please retry."
    fi
done

# Create the accept_license.exp script with expect commands
cat << EOF > accept_license.exp
#!/usr/bin/expect

set timeout 3600

spawn /tmp/qt-installer.run --email ${QT_USER} --root /root/Qt --password ${QT_PASSWORD} --platform minimal --accept-licenses --confirm-command install qt.qt5.5152.qtpdf qt.qt5.5152.qtpurchasing qt.qt5.5152.qtvirtualkeyboard qt.qt5.5152.qtquicktimeline qt.qt5.5152.qtlottie qt.qt5.5152.debug_info qt.qt5.5152.qtscript qt.qt5.5152.qtcharts qt.qt5.5152.qtwebengine qt.qt5.5152.qtwebglplugin qt.qt5.5152.qtnetworkauth qt.qt5.5152.qtwaylandcompositor qt.qt5.5152.qtdatavis3d qt.qt5.5152.logs qt.qt5.5152 qt.qt5.5152.src qt.qt5.5152.gcc_64 qt.qt5.5152.qtquick3d

expect {
    "Accept|Reject" {
        send "${LICENSE_PROMPT}\r"
        exp_continue
    }
    "Yes|No" {
        send "${TELEMETRY_PROMPT}\r"
        exp_continue
    }
    timeout {
        send_user "Timeout waiting for input\n"
        exit 1
    }
    eof {
        send_user "End of file reached\n"
        exit 0
    }
    default {
        exp_continue
    }
}
EOF

# Make the new script executable
chmod +x accept_license.sh

# Build Docker image
docker build --load -t openrv_rocky9 .


# Verify the target container has been stopped 
if [ "$(docker ps -q --filter name=^openrv_cont$)" ]; then
    docker stop openrv_cont
    echo "Stopped the container openrv_container"
fi
# Verify target container doesn't exist and remove if it does
if [ "$(docker ps -aq --filter name=^openrv_container$)" ]; then
    docker rm -f openrv_container
    echo "Removed docker container openrv_container"
fi

# Run the container
echo "Running the container openrv_container...."
docker run --name openrv_container -d openrv_rocky9 tail -f /dev/null

echo "Retrieving the OpenRV build name from the docker image"

BUILD_NAME=$(docker exec openrv_container /bin/bash -c "source /etc/environment && echo \${BUILD_NAME}")

echo "Copying the OpenRV build name from the docker image"

docker cp openrv_container:/OpenRV/${BUILD_NAME}.tar.gz $PWD/

if [ "$(docker ps -aq --filter name=^openrv_container$)" ]; then
    echo "Build completed. The OpenRV build has been copied to $PWD/${BUILD_NAME}.tar.gz"
else
    echo "Build failed. The file /OpenRV/${BUILD_NAME} is not present."
    docker rm openrv_cont
    exit 1
fi

# Verify the target container has been stopped 
if [ "$(docker ps -q --filter name=^openrv_cont$)" ]; then
    docker stop openrv_container
    echo "Stopped the container openrv_container"
fi

# Verify target container doesn't exist and remove if it does
if [ "$(docker ps -aq --filter name=^openrv_container$)" ]; then
    docker rm -f openrv_container
    echo "Removed docker container openrv_container"
fi


