#!/bin/bash

# Check if SQL_URI key exists in the .env file
if grep -q "^SQL_URIO=" "/home/csye6225/webapp/.env"; then
    echo "SQL_URI key already exists in the .env file."
else
    echo "Adding SQL_URI to the .env file."
    echo "SQL_URI=mysql://${name}:${password}@${host}:${port}/" | sudo tee -a "/home/csye6225/webapp/.env" > /dev/null
    echo "DATABASE=${database}" | sudo tee -a "/home/csye6225/webapp/.env" > /dev/null
    # Only create the .env_ready file if SQL_URI is added
    touch "/tmp/.env_ready"
    echo ".env_ready file created in /tmp."
fi
