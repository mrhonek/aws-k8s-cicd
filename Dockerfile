# Use Node.js LTS version
FROM node:20-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY src/package*.json ./

# Install dependencies
RUN npm ci --only=production

# Bundle app source
COPY src/ .

# Expose port
EXPOSE 3000

# Start the application
CMD [ "npm", "start" ]
