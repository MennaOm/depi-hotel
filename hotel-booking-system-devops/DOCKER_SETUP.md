# Docker Setup Guide

This project includes Docker Compose configuration to run the entire hotel booking system with frontend, backend, and MongoDB.

## Prerequisites

- Docker installed on your system
- Docker Compose installed (usually comes with Docker Desktop)

## Services

The Docker Compose setup includes three services:

1. **MongoDB** - Database service running on port 27017
2. **Backend** - Node.js/Express API server running on port 3000
3. **Frontend** - React/Vite application served via Nginx on port 80

## Environment Variables

Before running, you may need to set up environment variables. Create a `.env` file in the root directory or set them in your environment:

### Backend Environment Variables

```env
MONGODB_URI=mongodb://admin:password@mongodb:27017
PORT=3000
CLOUDINARY_CLOUD_NAME=your_cloudinary_cloud_name
CLOUDINARY_API_KEY=your_cloudinary_api_key
CLOUDINARY_API_SECRET=your_cloudinary_api_secret
CLERK_SECRET_KEY=your_clerk_secret_key
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret
```

### Frontend Environment Variables (Build Time)

These are set in `docker-compose.yml` as build arguments:
- `VITE_BACKEND_URL` - Backend API URL (default: http://localhost:3000)
- `VITE_CURRENCY` - Currency symbol (default: $)

## Usage

### Build and Start All Services

```bash
docker-compose up --build
```

This will:
- Build Docker images for frontend and backend
- Start MongoDB, backend, and frontend services
- Create a Docker network for service communication

### Start Services in Detached Mode

```bash
docker-compose up -d --build
```

### Stop All Services

```bash
docker-compose down
```

### Stop and Remove Volumes (including database data)

```bash
docker-compose down -v
```

### View Logs

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs backend
docker-compose logs frontend
docker-compose logs mongodb
```

### Rebuild After Code Changes

```bash
docker-compose up --build
```

## Accessing the Application

- **Frontend**: http://localhost:80 or http://localhost
- **Backend API**: http://localhost:3000
- **MongoDB**: localhost:27017

## MongoDB Credentials

Default MongoDB credentials (set in docker-compose.yml):
- Username: `admin`
- Password: `password`

**Note**: Change these credentials in production!

## Development vs Production

### Development Mode

For development, you might want to mount your source code as volumes to see changes without rebuilding. The backend already has volume mounting configured.

### Production Mode

For production:
1. Update environment variables with production values
2. Change MongoDB credentials
3. Update `VITE_BACKEND_URL` to your production backend URL
4. Consider using environment-specific configuration files

## Troubleshooting

### Port Already in Use

If ports 80, 3000, or 27017 are already in use, you can change them in `docker-compose.yml`:

```yaml
ports:
  - "8080:80"  # Change frontend port
  - "3001:3000"  # Change backend port
  - "27018:27017"  # Change MongoDB port
```

### Database Connection Issues

Ensure MongoDB service starts before the backend. The `depends_on` directive handles this automatically.

### Frontend Can't Connect to Backend

If the frontend can't reach the backend:
1. Check that `VITE_BACKEND_URL` in docker-compose.yml matches your backend URL
2. Ensure CORS is properly configured in the backend
3. Check that both services are running: `docker-compose ps`

## Building Individual Images

You can also build images individually:

```bash
# Build backend image
docker build -t hotel-booking-backend ./server

# Build frontend image
docker build -t hotel-booking-frontend ./client
```





