#!/bin/bash
# Usage: cc-db-query.sh "<SQL>"
# Run on CCVM. Executes a SQL query against the command_center database.
# Example: cc-db-query.sh "SELECT id, name, status FROM vpsas LIMIT 10;"
mysql -u root command_center -e "$1"
