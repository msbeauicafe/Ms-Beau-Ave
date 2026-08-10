// Vercel entry point for the MS BEAU AVE operations app.
//
// The app is a plain Node request handler, so the serverless function is just
// that handler. It is mounted at /ops (see vercel.json) and reaches Postgres
// through DATABASE_URL — on the shared Supabase project the engine lives in
// the `msbeau` schema, set via DB_SCHEMA, because `public` already holds the
// older demo site's own tables.
//
// Required environment variables (Vercel → Settings → Environment Variables):
//   DATABASE_URL    postgres connection string (use the Supabase pooler URI)
//   SESSION_SECRET  any long random string; without it every deploy signs out
//   DB_SCHEMA       msbeau
//   BASE_PATH       /ops
import { handleRequest } from '../../app/server.js';

export default handleRequest;

// Sessions are cookie-based, so the body parser is all we need from Vercel.
export const config = { api: { bodyParser: { sizeLimit: '1mb' } } };
