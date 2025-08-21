-- Streamlit Deployment Tracking Schema
-- Creates tables for managing deployment metadata and webhook mappings

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Main deployments table
CREATE TABLE IF NOT EXISTS deployments (
    id SERIAL PRIMARY KEY,
    app_name VARCHAR(255) UNIQUE NOT NULL,
    github_url VARCHAR(500) NOT NULL,
    main_file VARCHAR(100) NOT NULL,
    secrets_content TEXT,
    region VARCHAR(50) NOT NULL,
    target_branch VARCHAR(100) NOT NULL,
    webhook_id VARCHAR(50),
    cloud_run_url VARCHAR(500),
    memory VARCHAR(10) DEFAULT '1Gi',
    cpu VARCHAR(10) DEFAULT '1',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for efficient webhook lookups (compound key)
CREATE INDEX IF NOT EXISTS idx_deployments_repo_branch 
ON deployments (github_url, target_branch);

-- Index for app name lookups
CREATE INDEX IF NOT EXISTS idx_deployments_app_name 
ON deployments (app_name);

-- Deployment history table for audit trail
CREATE TABLE IF NOT EXISTS deployment_history (
    id SERIAL PRIMARY KEY,
    app_name VARCHAR(255) NOT NULL,
    deployment_type VARCHAR(20) NOT NULL, -- 'manual' or 'webhook'
    commit_sha VARCHAR(40),
    pusher_name VARCHAR(100),
    status VARCHAR(20) NOT NULL, -- 'success', 'failed', 'in_progress'
    error_message TEXT,
    deployed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (app_name) REFERENCES deployments(app_name) ON DELETE CASCADE
);

-- Index for deployment history lookups
CREATE INDEX IF NOT EXISTS idx_deployment_history_app_name 
ON deployment_history (app_name);

CREATE INDEX IF NOT EXISTS idx_deployment_history_deployed_at 
ON deployment_history (deployed_at DESC);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at on deployments table
DROP TRIGGER IF EXISTS update_deployments_updated_at ON deployments;
CREATE TRIGGER update_deployments_updated_at
    BEFORE UPDATE ON deployments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert initial admin user if not exists (for testing)
-- This should be replaced with proper user management in production
DO $$
BEGIN
    -- This is just a placeholder - Rundeck manages its own user system
    PERFORM 1; -- No-op, keeping for future use
END
$$;

-- Sample queries for common operations:

-- Query: Find deployment by repository and branch
-- SELECT * FROM deployments WHERE github_url = 'https://github.com/user/repo' AND target_branch = 'main';

-- Query: Get all deployments for a repository (all branches)
-- SELECT * FROM deployments WHERE github_url = 'https://github.com/user/repo';

-- Query: Get deployment history for an app
-- SELECT * FROM deployment_history WHERE app_name = 'my-app' ORDER BY deployed_at DESC LIMIT 10;

-- Query: Get recent deployments across all apps
-- SELECT d.app_name, d.github_url, d.target_branch, dh.deployed_at, dh.deployment_type 
-- FROM deployments d 
-- JOIN deployment_history dh ON d.app_name = dh.app_name 
-- WHERE dh.deployed_at > NOW() - INTERVAL '24 hours' 
-- ORDER BY dh.deployed_at DESC;