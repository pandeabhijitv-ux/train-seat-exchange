# Render Deployment Checklist

This checklist is for the current production design:

1. FastAPI backend on Render Starter
2. Persistent disk for SQLite train files
3. Firebase Phone Auth for user verification
4. PNR lookup via RapidAPI

Estimated recurring cost:

1. Render Starter web service: `$7/month`
2. Persistent disk 2 GB: `$0.50/month`
3. Estimated total: `~$7.50/month` plus bandwidth if usage grows

## Render Service Setup

1. Push this repository to GitHub.
2. In Render, create a new `Web Service` from the repo.
3. Region: `Singapore` is fine for India-focused traffic.
4. Plan: `Starter`.
5. Root directory: leave default if using the checked-in [render.yaml](render.yaml).

## Persistent Disk Setup

After creating the service:

1. Open the service in Render.
2. Go to `Disks`.
3. Add disk.
4. Size: `2 GB`.
5. Mount path: `/opt/render/project/src/backend/data`

This mount path matches [render.yaml](render.yaml).

## Render Environment Variables

Set these values:

1. `ENVIRONMENT=production`
2. `DEBUG=false`
3. `DB_FOLDER=/opt/render/project/src/backend/data`
4. `RAPIDAPI_KEY=your_rapidapi_key`
5. `FIREBASE_PROJECT_ID=your_firebase_project_id`
6. `FIREBASE_CREDENTIALS_PATH=/etc/secrets/firebase-service-account.json`

Optional only if you actually use payments later:

1. `RAZORPAY_KEY_ID=your_key`
2. `RAZORPAY_KEY_SECRET=your_secret`

You do not need `MSG91_AUTH_KEY` for the Firebase production path.

## Render Secret File

Add this secret file in Render:

1. File path: `/etc/secrets/firebase-service-account.json`
2. File contents: the Firebase service-account JSON from Firebase Console

If you prefer env vars instead of a secret file, use `FIREBASE_SERVICE_ACCOUNT_JSON` and update the Render env list accordingly.

## Health Check

Use:

1. `/health`

## First Deploy Smoke Test

After deploy:

1. Open `https://your-service.onrender.com/`
2. Open `https://your-service.onrender.com/docs`
3. Confirm `https://your-service.onrender.com/health`
4. Confirm the mounted disk path is used by creating a test entry and checking that files appear under the mounted data directory

## Important Notes

1. This app uses one SQLite file per `train number + date`.
2. Do not use Render's ephemeral filesystem for train exchange data.
3. A persistent disk means one service instance only, which is acceptable for your current scale.