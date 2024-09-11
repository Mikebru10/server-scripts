#Docker Graceful Shutdown
#!/bin/bash

# Script to stop all Docker containers gracefully

echo "Starting the shutdown of all Docker containers..."

# List all running Docker containers
containers=$(docker ps -q)

# Check if there are any containers running
if [ -z "$containers" ]; then
    echo "No Docker containers are running."
else
    # Stop all running containers
    echo "Stopping the following Docker containers:"
    docker ps
    
  # Using `docker stop` to gracefully stop containers
    docker stop $containers

    # Check if containers were stopped
    if [ $? -eq 0 ]; then
        echo "All containers have been stopped successfully."
    else
        echo "There was an error stopping the containers."
    fi
fi
