#!/bin/bash

http POST $SERVER/api/v1/protected/organizations \
  "Authorization:Bearer $AUTH_TOKEN" \
  name="$NAME" \
  description="$DESCRIPTION"