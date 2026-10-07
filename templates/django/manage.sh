#!/usr/bin/env bash

uv venv
source .venv/bin/activate

uv pip install django

django-admin startproject config .
python manage.py migrate