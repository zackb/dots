#!/bin/bash
host=$1
awk -v host="$host" '
  $1 == "machine" && $2 == host {
    getline; login = $2; 
    getline; password = $2;
    print password;
    exit;
  }
' ~/.netrc

