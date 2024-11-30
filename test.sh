#!/bin/bash
set -e 


OLD_COST=$(jq -r '.totalMonthlyCost' old_config.json)
NEW_COST=$(jq -r '.totalMonthlyCost' updated_config.json)

CHANGE=$(echo "scale=2; ($NEW_COST - $OLD_COST) / $OLD_COST * 100" | bc)

if (( $(echo "$CHANGE > 20" | bc -l) )); then
	echo "Kostenänderung überschreitet 20%! Aktuelle Änderung: $CHANGE%"
        exit 1
fi
