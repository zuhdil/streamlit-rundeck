# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Docker Compose configuration for running Rundeck, an open-source automation service with web console, command line tools, and WebAPI. The setup includes:

- **Rundeck**: Job scheduler and runbook automation (version 5.14.1)
- **PostgreSQL**: Database backend (version 17)

## Common Commands

### Starting the Environment
```bash
# Start all services in detached mode
docker compose up -d

# Start with logs visible
docker compose up

# Stop all services
docker compose down

# Stop and remove volumes (destructive)
docker compose down -v
```

### Managing Services
```bash
# View running containers
docker compose ps

# View logs for specific service
docker compose logs rundeck
docker compose logs db

# Follow logs in real-time
docker compose logs -f rundeck

# Restart a specific service
docker compose restart rundeck
```

### Accessing the Application
- **Rundeck Web Interface**: http://localhost:4440
- **Database**: localhost:5432 (exposed only to Docker network by default)

## Architecture

### Service Configuration
- **Database Service (`db`)**:
  - Uses official PostgreSQL 17 image
  - Database name: `rundeck`
  - User/Password: `rundeck`/`rundeckpassword`
  - Data persisted in `postgres-data` volume

- **Rundeck Service (`rundeck`)**:
  - Uses official Rundeck 5.14.1 image  
  - Depends on database service
  - Web interface on port 4440
  - Data and logs persisted in separate volumes (`rundeck-data`, `rundeck-logs`)

### Data Persistence
Three named volumes ensure data persistence across container restarts:
- `postgres-data`: PostgreSQL database files
- `rundeck-data`: Rundeck server data
- `rundeck-logs`: Rundeck application logs

### Environment Variables
Key configuration is handled through environment variables in the compose file:
- Database connection settings
- Rundeck URL configuration
- Database driver specification

## Development Notes

Since this is a Docker Compose infrastructure setup rather than a code development project, most work involves:
- Modifying service configurations in `compose.yml`
- Adding new services or dependencies
- Adjusting environment variables and volume mounts
- Networking configuration between services

## Git Commit Guidelines

When committing changes to this repository:
- Use short, descriptive commit messages
- Do not include signatures or additional metadata in commit messages
- Focus on what was changed, not why or how