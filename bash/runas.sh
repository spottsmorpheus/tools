#!/bin/bash
echo "This is $USER"
echo "Source Path is $BASH_SOURCE"
echo "pwd $PWD"
SCRIPTROOT=$(dirname "$BASH_SOURCE")
echo "Script Root $SCRIPTROOT"
