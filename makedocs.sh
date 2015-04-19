#!/bin/sh

sourcekitten doc > sourcek.json && jazzy -s sourcek.json --min-acl public -c