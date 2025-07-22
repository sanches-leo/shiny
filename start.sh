#!/bin/bash

echo "Cleaning up old user directories..."
find users/ -mindepth 1 -maxdepth 1 -type d -atime +10 ! -name 'test' -exec rm -rf {} \;

echo "Starting Docker Compose..."
docker compose up -d

if [ $? -ne 0 ]; then
    echo "Docker Compose failed to start."
    exit 1
fi

echo "Docker Compose started successfully."

# Wait for the shiny service to be running
while [ -z "$(docker compose ps -q shiny)" ] || [ "$(docker compose ps -q shiny | xargs docker inspect -f '{{.State.Running}}')" != "true" ]; do
    sleep 1
done

docker compose ps

echo ""
echo "The application is running on http://localhost:3838"

echo "Waiting 10 seconds for the server to start..."
sleep 10

# Open the URL in the default browser
if command -v xdg-open >/dev/null; then
    xdg-open http://localhost:3838
elif command -v gnome-open >/dev/null; then
    gnome-open http://localhost:3838
elif command -v open >/dev/null; then
    open http://localhost:3838
else
    echo "Could not detect the web browser to open the URL."
    echo "Please open http://localhost:3838 in your web browser."
fi

echo "Press any key to stop the application and remove the containers."
read -n 1 -s -r

echo ""
echo "Stopping Docker Compose..."
docker compose down

echo "Docker Compose stopped."
