# Backup and Restore

This project currently launches on a one-VM architecture, so backup coverage must include both:

- PostgreSQL data
- `backend/uploads/` file storage

If either side is missing, restore quality is incomplete.

## What to back up

- PostgreSQL database referenced by `DATABASE_URL`
- Uploaded files under `/var/www/believer/backend/uploads/`
- The production env file used by `believer-backend`

## PostgreSQL backup command

Example custom-format backup command:

```bash
mkdir -p /var/backups/believer
PGPASSWORD='<db-password>' pg_dump \
  --format=custom \
  --no-owner \
  --clean \
  --if-exists \
  --file /var/backups/believer/believer_$(date +%F_%H%M%S).dump \
  --host 127.0.0.1 \
  --port 5432 \
  --username postgres \
  believer
```

If production uses Azure Database for PostgreSQL instead of local Postgres, keep the same `pg_dump` format and point the command at the managed database host.

## Uploads backup note

The backend stores uploaded files on disk under `backend/uploads/`, with mosque images under `backend/uploads/mosques/`.

Example archive command:

```bash
sudo tar -czf /var/backups/believer/uploads_$(date +%F_%H%M%S).tar.gz \
  -C /var/www/believer/backend \
  uploads
```

If you already snapshot the VM disk, keep this directory in scope and ensure the snapshot timing lines up with the database backup you intend to restore with.

## Backup expectations for launch

- Take a PostgreSQL backup immediately before running production migrations.
- Capture `backend/uploads/` in the same pre-deploy window.
- Keep backups outside `/var/www/believer/` so deploy cleanup cannot remove them.
- Name backups with a timestamp and release identifier when possible.
- Periodically test a restore on a non-production environment before public launch.

## Restore outline

1. Put the app in maintenance mode if you have a standard process, or stop new writes by stopping the backend:

```bash
sudo systemctl stop believer-backend
```

2. Restore PostgreSQL from the chosen backup:

```bash
PGPASSWORD='<db-password>' pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --dbname=postgresql://postgres:<db-password>@127.0.0.1:5432/believer \
  /var/backups/believer/believer_<timestamp>.dump
```

3. Restore uploads from the matching archive:

```bash
sudo tar -xzf /var/backups/believer/uploads_<timestamp>.tar.gz \
  -C /var/www/believer/backend
```

4. Start the backend again:

```bash
sudo systemctl start believer-backend
sudo systemctl status believer-backend
```

5. Validate the restore:

- `curl https://api.example.com/health`
- Load the frontend and confirm data renders
- Open a record with an uploaded image and confirm the file resolves
- Check backend logs for migration or startup errors

## Restore cautions

- Database restore and uploads restore should come from the same checkpoint whenever possible.
- Restoring only the database can break uploaded file references.
- Restoring only uploads can leave files with no database references.
- If DNS, Nginx, or env configuration changed during the incident, fix those separately because the database restore will not correct them.
