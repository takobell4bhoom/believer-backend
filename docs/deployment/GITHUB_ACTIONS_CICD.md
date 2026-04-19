# GitHub Actions CI/CD

This repo now includes a production deploy workflow at `.github/workflows/production-deploy.yml`.

## What it does

On every push to `main`, plus manual `workflow_dispatch` runs, GitHub Actions will:

1. Run Flutter analyze and tests.
2. Run backend syntax, smoke, and integration tests.
3. Build the Flutter web release with the production `API_BASE_URL`.
4. Package the built frontend as `believer-web.tar.gz` and store it as a GitHub artifact.
5. Upload that tarball to the Ubuntu server over SSH.
6. Run `deploy/scripts/deploy_release.sh` on the server so the VM pulls the latest repo code, swaps in the new frontend build, runs backend migrations, restarts `believer-backend`, and reloads Nginx.

## Required GitHub secrets

Add these repository secrets in GitHub:

- `PROD_API_BASE_URL`
  Example: `https://api.believerslens.com`
- `PROD_HOST`
  Example: `app.believerslens.com` or the server IP
- `PROD_USER`
  SSH user GitHub should log in as
- `PROD_SSH_PRIVATE_KEY`
  Private key matching the public key installed for `PROD_USER` on the server

Optional secrets:

- `PROD_PORT`
  Defaults to `22`
- `PROD_APP_DIR`
  Defaults to `/var/www/believer`
- `PROD_APP_USER`
  Defaults to `PROD_USER`
- `PROD_APP_GROUP`
  Defaults to `PROD_APP_USER`
- `PROD_KNOWN_HOSTS`
  Recommended. Paste the output of:

  ```bash
  ssh-keyscan -H your-server-hostname
  ```

  If this secret is omitted, the workflow will run `ssh-keyscan` during deploy.

## One-time server requirements

Before enabling deploys from GitHub, make sure the Ubuntu host already has:

- The repo cloned at `/var/www/believer` or your chosen `PROD_APP_DIR`
- `backend/.env` created from `backend/.env.production.example`
- Nginx configured
- `believer-backend` systemd service installed
- Docker installed and working for the backend Postgres service

If you still need the initial machine setup, use:

```bash
REPO_URL=https://github.com/<owner>/<repo>.git \
WEB_SOURCE_DIR=/tmp/believer-web \
bash deploy/scripts/setup_hosting.sh
```

`deploy/scripts/setup_hosting.sh` still expects a prebuilt frontend directory for the very first setup. After the first successful setup, GitHub Actions handles the later releases.

## Passwordless sudo

The deploy workflow runs the existing release script remotely, and that script uses `sudo` for:

- restarting `believer-backend`
- validating and reloading Nginx
- refreshing `build/web`
- ensuring the backend Postgres container is up

Because GitHub deploys are non-interactive, the SSH deploy user needs passwordless sudo for those actions. The release script now checks this up front and exits with a clear message if `sudo -n` is not allowed.

A minimal sudoers drop-in often looks like this:

```text
deployuser ALL=(ALL) NOPASSWD: /bin/systemctl restart believer-backend, /bin/systemctl reload nginx, /usr/sbin/nginx, /usr/bin/docker, /bin/mv, /bin/rm, /bin/chown
```

Adjust the username and command paths for your server. Validate with:

```bash
ssh deployuser@your-server 'sudo -n true'
```

## Deploy flow

The remote release still uses this layout:

```text
/var/www/believer/
  backend/
  build/web/
```

The workflow uploads `/tmp/believer-web.tar.gz`, extracts it into `/tmp/believer-web`, and then runs:

```bash
APP_DIR=/var/www/believer \
WEB_SOURCE_DIR=/tmp/believer-web \
bash /var/www/believer/deploy/scripts/deploy_release.sh
```

That script:

- pulls the latest Git branch on the server
- runs `npm ci`
- replaces `build/web`
- starts or reuses the backend Postgres container
- runs migrations
- restarts the backend
- validates and reloads Nginx

## Recommended first test

1. Add the GitHub secrets.
2. Push this config to GitHub.
3. Run the `Production Deploy` workflow manually from the Actions tab.
4. Confirm the workflow finishes successfully.
5. On the server, verify:

```bash
cd /var/www/believer/backend && docker compose ps
sudo systemctl status believer-backend --no-pager
curl http://127.0.0.1:4000/health
```

Then open the frontend in the browser and confirm API calls point at the same `PROD_API_BASE_URL`.
