# NEET Mock Test Backend

Express + MySQL API for database-driven mock tests.

## Endpoints

- `GET /health`
- `GET /mocktest/:setNumber`

## Environment

Copy `.env.example` to `.env` and set your MySQL credentials.

## Run

```bash
npm install
npm start
```

The API serves set data from the `neet_app.questions` table and returns questions ordered by `qno`.
