#!/bin/bash
host=$1
field=${2:-password}

awk -v host="$host" -v field="$field" '
  $1 == "machine" && $2 == host {
    getline; login = $2;
    getline; password = $2;
    if (field == "username" || field == "login") {
      print login;
    } else {
      print password;
    }
    exit;
  }
' /home/zackb/.netrc
