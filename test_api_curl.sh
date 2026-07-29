#!/bin/bash
curl -X POST http://192.168.0.57:8080/assessorReport2/mobile/get_arpl_toolkit_data.php \
  -H "Content-Type: application/json" \
  -d '{"learnerID":72,"classID":783,"ofoNumber":"671103"}' \
  2>&1 | head -100
