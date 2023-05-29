#!/bin/bash

echo "Clearing namespace"
sed -i "" "s|\"namespace\": \"GW_Volunteers\"|\"namespace\": \"\"|" sfdx-project.json

echo "Cleaning previous scratch org..."
sf org delete scratch --no-prompt --target-org V4S

echo "Creating new scratch org"
sf org create scratch --definition-file config/project-scratch-def.json --duration-days 21 --alias V4S --no-namespace --set-default

echo "Pushing metadata"
sf project deploy start --manifest src/package.xml

echo "Adding sample data"
sf data import tree --plan ./data/data-plan.json

echo "Replace namespace"
sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"GW_Volunteers\"|" sfdx-project.json

echo "opening org"
sf org open

echo "Org is set up"