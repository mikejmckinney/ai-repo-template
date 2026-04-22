# Configuration Templates

> **Purpose**: Deployment configuration templates for common platforms. Copy and customize for your project.

## Available Templates

| File | Platform | Purpose |
|------|----------|---------|
| `vercel.json.template` | Vercel | Frontend deployment, serverless functions |
| `railway.toml.template` | Railway | Backend services, databases |
| `render.yaml.template` | Render | Full-stack deployment blueprint |
| `docker-compose.yml.template` | Docker | Local development environment |

## Usage

1. Copy the template you need to your project root
2. Remove the `.template` extension
3. Replace placeholder values with your actual configuration
4. Remove the `TEMPLATE_PLACEHOLDER` comment

## Platform Recommendations

### Choosing the Right Platform

| Use Case | Recommended Platform | Why |
|----------|---------------------|-----|
| Static sites / SPAs | Vercel, Netlify | Free, fast CDN, easy deploys |
| Next.js / React SSR | Vercel | First-party support, optimized |
| Node.js API | Railway, Render | Easy setup, free tier |
| Python/Go/Rust API | Railway, Render | Multi-language support |
| PostgreSQL database | Supabase, Railway | Managed, free tier |
| Redis cache | Upstash, Railway | Serverless options |
| Background jobs | Railway, Render | Worker process support |
| Full-stack monorepo | Render Blueprint | Single config for all services |

### Serverless vs. Containers

**Use Serverless (Vercel, Netlify Functions, AWS Lambda) when:**
- Traffic is spiky or unpredictable
- Functions are stateless and short-lived
- You want zero infrastructure management
- Cost optimization for low-traffic apps

**Use Containers (Railway, Render, Fly.io) when:**
- You need persistent connections (WebSockets, database pools)
- Long-running processes or background jobs
- Predictable traffic patterns
- More control over runtime environment

**Avoid Kubernetes unless:**
- You have 10+ microservices
- Need complex orchestration (auto-scaling, service mesh)
- Have dedicated DevOps resources
- The complexity is justified by scale

## Environment Variables

### Required Secrets

Most deployments need these secrets configured:

| Secret | Purpose | Where to Set |
|--------|---------|--------------|
| `DATABASE_URL` | Database connection string | Platform dashboard |
| `API_KEY` | External API authentication | Platform dashboard |
| `JWT_SECRET` | Token signing | Platform dashboard (generate) |

### GitHub Secrets for Workflows

The CI workflows in this template use these secrets:

| Secret | Required By | Purpose |
|--------|-------------|---------|
| `BACKEND_URL` | `keep-warm.yml`, `validate-connections.yml` | Backend health endpoint |
| `VERCEL_TOKEN` | Deploy workflows (if added) | Vercel API access |
| `RAILWAY_TOKEN` | Deploy workflows (if added) | Railway API access |

Set these in: **GitHub repo → Settings → Secrets and variables → Actions**

## Example: Full Deployment Setup

### 1. Frontend on Vercel

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy (first time - creates project)
vercel

# Deploy to production
vercel --prod
```

### 2. Backend on Railway

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Deploy
railway up
```

### 3. Connect Frontend to Backend

In Vercel dashboard:
1. Go to Settings → Environment Variables
2. Add `NEXT_PUBLIC_API_URL` = your Railway backend URL
3. Redeploy

## Troubleshooting

### Vercel
- **Build fails**: Check `buildCommand` matches your package.json scripts
- **API routes 404**: Ensure `/api` folder structure is correct
- **Slow cold starts**: Consider Edge Functions for latency-sensitive routes

### Railway
- **Deploy stuck**: Check build logs, ensure `startCommand` is correct
- **Database connection fails**: Verify `DATABASE_URL` is set
- **Out of memory**: Upgrade plan or optimize memory usage

### Render
- **Service suspended**: Free tier suspends after 15 min inactivity (use `keep-warm.yml`)
- **Slow builds**: Add `.dockerignore` to exclude `node_modules`, etc.
- **Health check fails**: Ensure `/health` endpoint returns 200

<!-- smoke-test marker C (PR #113 verification, will be closed unmerged) -->
