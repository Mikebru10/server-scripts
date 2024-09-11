#Start All Docker Containers
#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, please install Docker."
    exit 1
fi

# Start all stopped Docker containers
docker start $(docker ps -aq)

echo "All Docker containers have been started."
