# Azure Ubuntu VM Deployment

This project can now be deployed to a single Ubuntu VM for staging or an initial production rollout:

- Flutter web frontend served by Nginx
- Fastify backend managed by `systemd`
- PostgreSQL either on the same VM or on Azure Database for PostgreSQL

## Recommended topologies

### Fastest path
- One Ubuntu VM
- Nginx
- Node backend on the VM
- PostgreSQL on the VM

### Better production path
- One Ubuntu VM
- Nginx
- Node backend on the VM
- Azure Database for PostgreSQL Flexible Server

## Important current constraints

- Uploaded mosque images are stored on local disk under `backend/uploads/`.
- That is acceptable for a single-VM deployment, but not ideal for horizontal scaling.
- The frontend is a static Flutter web build and must be built with `--dart-define=API_BASE_URL=...`.
- The backend now supports proxy-aware upload URLs through `TRUST_PROXY=true` and `PUBLIC_API_ORIGIN=https://api.example.com`.

For public-launch operations, also use:

- `docs/deployment/PUBLIC_LAUNCH_RUNBOOK.md`
- `docs/deployment/BACKUP_RESTORE.md`
- `docs/deployment/PUBLIC_QA_CHECKLIST.md`

## Build commands

From the repo root:

```bash
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
npm ci
npm run backend:migrate
```

## Backend env

Start from:

- `backend/.env.production.example`

Minimum production values:

- `NODE_ENV=production`
- `HOST=127.0.0.1`
- `PORT=4000`
- `TRUST_PROXY=true`
- `DATABASE_URL=...`
- `JWT_SECRET=...`
- `RESEND_API_KEY=...`
- `EMAIL_FROM=...`
- `EMAIL_REPLY_TO=...`
- `APP_WEB_ORIGIN=https://app.example.com`
- `PASSWORD_RESET_URL_BASE=https://app.example.com/#/reset-password`
- `PASSWORD_RESET_TOKEN_TTL_MINUTES=60`
- `CORS_ORIGIN=https://app.example.com`
- `PUBLIC_API_ORIGIN=https://api.example.com`
- `GOOGLE_MAPS_API_KEY=...` if used in production
- `ALADHAN_BASE_URL=https://api.aladhan.com/v1`
- `ALADHAN_TIMEOUT_MS=5000`

## Ubuntu file layout

Recommended layout:

```text
/var/www/believer/
  backend/
  build/web/
```

## systemd

Template file:

- `deploy/systemd/believer-backend.service`

Install:

```bash
sudo cp /var/www/believer/deploy/systemd/believer-backend.service /etc/systemd/system/believer-backend.service
sudo systemctl daemon-reload
sudo systemctl enable believer-backend
sudo systemctl start believer-backend
sudo systemctl status believer-backend
```

## Nginx

Template file:

- `deploy/nginx/believer.conf`

Install:

```bash
sudo cp /var/www/believer/deploy/nginx/believer.conf /etc/nginx/sites-available/believer
sudo ln -s /etc/nginx/sites-available/believer /etc/nginx/sites-enabled/believer
sudo nginx -t
sudo systemctl reload nginx
```

Then add HTTPS with Certbot after DNS is pointed correctly.

## Health checks

Backend:

```bash
curl http://127.0.0.1:4000/health
curl https://api.example.com/health
```

Frontend build origin check:

```bash
grep -R "https://api.example.com" build/web
```

## Post-deploy smoke checks

- Load the frontend
- Create/login account
- Load nearby mosques
- Open one mosque page
- Upload one mosque image
- Create one mosque as admin
- Confirm image URLs are returned as `https://...`
- Validate `app.example.com` and `api.example.com` DNS/HTTPS before public traffic
- Confirm `CORS_ORIGIN` and Flutter `API_BASE_URL` point to the same public environment
