#!/bin/bash
# Usage: cc-db-query.sh "<SQL>"
# Run on CCVM. Executes a SQL query against the Command Center database.
# DB name is "command-center" (with hyphen). Uses PostgreSQL (newer builds) or MySQL.
# Example: cc-db-query.sh "SELECT email, authentication_token FROM users LIMIT 5;"
sudo -u postgres psql "command-center" -c "$1" 2>/dev/null \
  || mysql -u root "command-center" -e "$1" 2>/dev/null
