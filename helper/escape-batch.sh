#!/bin/bash
cat $1 | sed -e 's/%/%%/g' -e 's/\^/^^/g' -e 's/&/^&/g' -e 's/|/^|/g' -e 's/</^</g' -e 's/>/^>/g'
